package com.skyai.app

import android.content.Context
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.navigation.NavController
import androidx.navigation.NavType
import androidx.navigation.compose.*
import androidx.navigation.navArgument
import com.google.gson.Gson
import com.skyai.app.data.model.*
import com.skyai.app.data.repository.SearchResultsCache
import com.skyai.app.ui.detail.FlightDetailScreen
import com.skyai.app.ui.home.HomeScreen
import com.skyai.app.ui.onboarding.OnboardingScreen
import com.skyai.app.ui.profile.ProfileScreen
import com.skyai.app.ui.results.ResultsScreen
import com.skyai.app.ui.results.ResultsViewModel
import com.skyai.app.ui.search.SearchScreen
import com.skyai.app.ui.search.SearchViewModel
import com.skyai.app.ui.theme.SkyAITheme
import com.skyai.app.ui.watchlist.WatchlistScreen
import dagger.hilt.android.AndroidEntryPoint
import java.net.URLDecoder
import java.net.URLEncoder

// ── Tab definition ────────────────────────────────────────────────────────────

sealed class Tab(val route: String, val label: String, val icon: ImageVector) {
    object Home      : Tab("home",      "Home",      Icons.Default.Home)
    object Search    : Tab("search",    "Search",    Icons.Default.Search)
    object Watchlist : Tab("watchlist", "Watchlist", Icons.Default.Notifications)
    object Profile   : Tab("profile",   "Profile",   Icons.Default.Person)
}

private val tabs = listOf(Tab.Home, Tab.Search, Tab.Watchlist, Tab.Profile)

// ── Activity ──────────────────────────────────────────────────────────────────

@AndroidEntryPoint
class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            SkyAITheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    SkyAIApp(context = applicationContext)
                }
            }
        }
    }
}

// ── Root composable ───────────────────────────────────────────────────────────

@Composable
fun SkyAIApp(context: Context) {
    // Simple on-device profile persistence using SharedPreferences + Gson
    val prefs = remember { context.getSharedPreferences("skyai_prefs", Context.MODE_PRIVATE) }
    val gson  = remember { Gson() }

    var profile by remember {
        val json = prefs.getString("user_profile", null)
        val saved = json?.let { runCatching { gson.fromJson(it, UserProfile::class.java) }.getOrNull() }
        mutableStateOf(saved ?: UserProfile())
    }

    fun saveProfile(p: UserProfile) {
        profile = p
        prefs.edit().putString("user_profile", gson.toJson(p)).apply()
    }

    if (!profile.isOnboardingComplete) {
        val navController = rememberNavController()
        NavHost(navController = navController, startDestination = "onboarding") {
            composable("onboarding") {
                OnboardingScreen(
                    navController = navController,
                    onComplete = { completed -> saveProfile(completed) }
                )
            }
        }
    } else {
        MainTabsHost(profile = profile, onProfileUpdate = { saveProfile(it) })
    }
}

// ── Tab host ──────────────────────────────────────────────────────────────────

@Composable
fun MainTabsHost(profile: UserProfile, onProfileUpdate: (UserProfile) -> Unit) {
    val navController       = rememberNavController()
    val navBackStackEntry   by navController.currentBackStackEntryAsState()
    val currentRoute        = navBackStackEntry?.destination?.route

    // Tabs show only on top-level tab routes
    val topLevelRoutes = tabs.map { it.route }
    val showBottomBar  = topLevelRoutes.any { currentRoute?.startsWith(it) == true }

    Scaffold(
        bottomBar = {
            if (showBottomBar) {
                NavigationBar(containerColor = MaterialTheme.colorScheme.surface) {
                    tabs.forEach { tab ->
                        val selected = currentRoute == tab.route
                        NavigationBarItem(
                            selected = selected,
                            onClick = {
                                if (!selected) {
                                    navController.navigate(tab.route) {
                                        popUpTo(Tab.Home.route) { saveState = true }
                                        launchSingleTop = true
                                        restoreState    = true
                                    }
                                }
                            },
                            icon = { Icon(tab.icon, contentDescription = tab.label) },
                            label = { Text(tab.label) },
                            colors = NavigationBarItemDefaults.colors(
                                selectedIconColor   = MaterialTheme.colorScheme.primary,
                                selectedTextColor   = MaterialTheme.colorScheme.primary,
                                indicatorColor      = MaterialTheme.colorScheme.primaryContainer
                            )
                        )
                    }
                }
            }
        }
    ) { paddingValues ->
        SkyAINavGraph(
            navController    = navController,
            profile          = profile,
            onProfileUpdate  = onProfileUpdate,
            modifier         = Modifier.padding(paddingValues)
        )
    }
}

// ── Nav graph ─────────────────────────────────────────────────────────────────

@Composable
fun SkyAINavGraph(
    navController: NavController,
    profile: UserProfile,
    onProfileUpdate: (UserProfile) -> Unit,
    modifier: Modifier = Modifier
) {
    val gson = remember { Gson() }

    NavHost(
        navController = navController as androidx.navigation.NavHostController,
        startDestination = Tab.Home.route,
        modifier = modifier.fillMaxSize()
    ) {

        // ── Tab screens ───────────────────────────────────────────────────

        composable(Tab.Home.route) {
            HomeScreen(navController = navController, profile = profile)
        }

        composable(Tab.Search.route) {
            val viewModel: SearchViewModel = hiltViewModel()
            SearchScreen(viewModel = viewModel, navController = navController)
        }

        composable(Tab.Watchlist.route) {
            WatchlistScreen(navController = navController)
        }

        composable(Tab.Profile.route) {
            ProfileScreen(
                navController   = navController,
                profile         = profile
            )
        }

        // ── Onboarding (edit profile) ─────────────────────────────────────

        composable("onboarding") {
            OnboardingScreen(
                navController = navController,
                onComplete    = { updated ->
                    onProfileUpdate(updated)
                    navController.popBackStack()
                }
            )
        }

        // ── Results ───────────────────────────────────────────────────────

        // Routes pass IDs only; the actual SearchResponse / FlightOffer is
        // looked up from SearchResultsCache. Previously we serialized the
        // whole 50-offer response into the route string, which blew past
        // Android's nav-arg size budget — `navigate()` silently failed and
        // the destination rendered blank.
        composable(
            route = "results/{queryId}",
            arguments = listOf(navArgument("queryId") { type = NavType.StringType })
        ) { backStackEntry ->
            val queryId  = backStackEntry.arguments?.getString("queryId")
            val response = queryId?.let { SearchResultsCache.get(it) }
            if (response != null) {
                val viewModel: ResultsViewModel = hiltViewModel()
                ResultsScreen(
                    viewModel      = viewModel,
                    navController  = navController,
                    searchResponse = response
                )
            }
        }

        // ── Flight Detail ─────────────────────────────────────────────────

        composable(
            route = "detail/{offerId}",
            arguments = listOf(navArgument("offerId") { type = NavType.StringType })
        ) { backStackEntry ->
            val offerId = backStackEntry.arguments?.getString("offerId")
            val offer   = offerId?.let { SearchResultsCache.getOffer(it) }
            if (offer != null) {
                FlightDetailScreen(navController = navController, offer = offer)
            }
        }
    }
}

// ── Nav helpers ───────────────────────────────────────────────────────────────
// Stash the payload in SearchResultsCache; route by ID only.

fun NavController.navigateToResults(response: SearchResponse) {
    SearchResultsCache.put(response)
    navigate("results/${response.queryId}")
}

fun NavController.navigateToDetail(offer: FlightOffer) {
    navigate("detail/${offer.offerId}")
}
