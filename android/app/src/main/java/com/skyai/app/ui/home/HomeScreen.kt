package com.skyai.app.ui.home

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshContainer
import androidx.compose.material3.pulltorefresh.rememberPullToRefreshState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavController
import androidx.navigation.compose.rememberNavController
import com.skyai.app.data.model.UserProfile
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private val PrimaryBlue = Color(0xFF1A3C6B)
private val AccentOrange = Color(0xFFFF6B35)
private val GreenSuccess = Color(0xFF00A651)
private val LightGray = Color(0xFFF8F9FA)
private val DarkGray = Color(0xFF49454E)

data class DealCard(
    val route: String,
    val originCode: String,
    val destCode: String,
    val airline: String,
    val price: Double,
    val percentageDown: Int,
    val priceLabel: String,
    val labelColor: Color,
    val duration: String,
    val flightType: String
)

data class CityChip(
    val city: String,
    val code: String,
    val price: Double,
    val isSteals: Boolean = false
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(navController: NavController, profile: UserProfile) {
    val pullRefreshState = rememberPullToRefreshState()
    val scope = rememberCoroutineScope()
    var isRefreshing by remember { mutableStateOf(false) }

    if (pullRefreshState.isRefreshing) {
        scope.launch {
            delay(1500)
            isRefreshing = false
            pullRefreshState.endRefresh()
        }
    }

    Box(Modifier.nestedScroll(pullRefreshState.nestedScrollConnection)) {
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.White),
            contentPadding = PaddingValues(bottom = 24.dp)
        ) {
            item {
                HeroHeader(profile = profile)
            }

            item {
                SearchBarCard(
                    onClick = { navController.navigate("search") }
                )
            }

            item {
                SectionTitle(
                    title = "Best value this week",
                    icon = "🔥"
                )
            }

            item {
                DealCardsSection()
            }

            item {
                SectionTitle(
                    title = "Cheapest from SFO",
                    icon = "🗺️"
                )
            }

            item {
                CityChipsSection()
            }
        }

        PullToRefreshContainer(
            modifier = Modifier.align(Alignment.TopCenter),
            state = pullRefreshState,
            containerColor = PrimaryBlue,
            contentColor = Color.White
        )
    }
}

@Composable
private fun HeroHeader(profile: UserProfile) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(180.dp)
            .background(
                brush = Brush.verticalGradient(
                    colors = listOf(
                        PrimaryBlue,
                        PrimaryBlue.copy(alpha = 0.85f)
                    )
                )
            ),
        contentAlignment = Alignment.BottomStart
    ) {
        // Watermark airplane icon
        Text(
            text = "✈️",
            fontSize = 120.sp,
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .alpha(0.08f)
                .offset(x = 20.dp, y = 40.dp)
        )

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(24.dp),
            verticalArrangement = Arrangement.Bottom
        ) {
            Text(
                text = "Good morning, ${profile.firstName} ✈️",
                style = MaterialTheme.typography.headlineSmall.copy(
                    color = Color.White,
                    fontWeight = FontWeight.Bold
                )
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = "Where are you flying next?",
                style = MaterialTheme.typography.bodyLarge.copy(
                    color = Color.White.copy(alpha = 0.85f)
                )
            )
        }
    }
}

@Composable
private fun SearchBarCard(onClick: () -> Unit) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .offset(y = (-28).dp)
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            Icon(
                imageVector = Icons.Default.Search,
                contentDescription = "Search",
                tint = DarkGray,
                modifier = Modifier.size(24.dp)
            )
            Text(
                text = "Search flights or cities...",
                style = MaterialTheme.typography.bodyMedium.copy(
                    color = DarkGray.copy(alpha = 0.6f)
                ),
                modifier = Modifier.weight(1f)
            )
            Icon(
                imageVector = Icons.Default.Mic,
                contentDescription = "Voice search",
                tint = DarkGray,
                modifier = Modifier.size(24.dp)
            )
        }
    }
}

@Composable
private fun SectionTitle(title: String, icon: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 20.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = icon,
            fontSize = 20.sp,
            modifier = Modifier.padding(end = 8.dp)
        )
        Text(
            text = title,
            style = MaterialTheme.typography.titleLarge.copy(
                fontWeight = FontWeight.Bold
            )
        )
    }
}

@Composable
private fun DealCardsSection() {
    val deals = listOf(
        DealCard(
            route = "SFO → NRT",
            originCode = "SFO",
            destCode = "NRT",
            airline = "NH",
            price = 842.0,
            percentageDown = 19,
            priceLabel = "STEAL",
            labelColor = AccentOrange,
            duration = "9h 55m",
            flightType = "Direct"
        ),
        DealCard(
            route = "SFO → ICN",
            originCode = "SFO",
            destCode = "ICN",
            airline = "OZ",
            price = 490.0,
            percentageDown = 34,
            priceLabel = "STEAL",
            labelColor = AccentOrange,
            duration = "11h 30m",
            flightType = "1 stop"
        ),
        DealCard(
            route = "SFO → DPS",
            originCode = "SFO",
            destCode = "DPS",
            airline = "GA",
            price = 389.0,
            percentageDown = 42,
            priceLabel = "STEAL",
            labelColor = AccentOrange,
            duration = "18h 15m",
            flightType = "2 stops"
        )
    )

    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        deals.forEach { deal ->
            DealCardItem(deal = deal)
        }
    }
}

@Composable
private fun DealCardItem(deal: DealCard) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable {},
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = deal.route,
                    style = MaterialTheme.typography.titleLarge.copy(
                        fontWeight = FontWeight.Bold
                    )
                )

                // Badge pill
                Surface(
                    modifier = Modifier
                        .background(deal.labelColor, shape = RoundedCornerShape(8.dp))
                        .padding(horizontal = 8.dp, vertical = 4.dp),
                    color = deal.labelColor
                ) {
                    Text(
                        text = deal.priceLabel,
                        style = MaterialTheme.typography.labelSmall.copy(
                            color = Color.White,
                            fontWeight = FontWeight.Bold
                        ),
                        modifier = Modifier.padding(4.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.height(12.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = "$${deal.price.toInt()}",
                        style = MaterialTheme.typography.headlineSmall.copy(
                            fontWeight = FontWeight.Bold,
                            color = PrimaryBlue
                        )
                    )
                    Text(
                        text = "↓${deal.percentageDown}% vs avg",
                        style = MaterialTheme.typography.bodySmall.copy(
                            color = GreenSuccess,
                            fontWeight = FontWeight.Bold
                        )
                    )
                }

                // Airline badge
                Surface(
                    modifier = Modifier
                        .background(PrimaryBlue, shape = RoundedCornerShape(8.dp))
                        .padding(8.dp),
                    color = PrimaryBlue
                ) {
                    Text(
                        text = deal.airline,
                        style = MaterialTheme.typography.labelSmall.copy(
                            color = Color.White,
                            fontWeight = FontWeight.Bold
                        ),
                        modifier = Modifier.padding(4.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            Text(
                text = "${deal.flightType} · ${deal.duration}",
                style = MaterialTheme.typography.bodySmall.copy(
                    color = DarkGray
                )
            )

            Spacer(modifier = Modifier.height(12.dp))

            FilledButton(
                onClick = {},
                modifier = Modifier.fillMaxWidth(),
                colors = androidx.compose.material3.ButtonDefaults.filledButtonColors(
                    containerColor = GreenSuccess
                )
            ) {
                Text(
                    text = "Book Now →",
                    style = MaterialTheme.typography.labelLarge.copy(
                        color = Color.White
                    )
                )
            }
        }
    }
}

@Composable
private fun CityChipsSection() {
    val cities = listOf(
        CityChip("Tokyo", "NRT", 842.0),
        CityChip("Seoul", "ICN", 490.0, isSteals = true),
        CityChip("Bali", "DPS", 389.0, isSteals = true),
        CityChip("Bangkok", "BKK", 520.0),
        CityChip("London", "LHR", 780.0),
        CityChip("Singapore", "SIN", 920.0)
    )

    LazyRow(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        contentPadding = PaddingValues(end = 16.dp)
    ) {
        items(cities) { city ->
            CityChipItem(city = city)
        }
    }
}

@Composable
private fun CityChipItem(city: CityChip) {
    Card(
        modifier = Modifier
            .width(110.dp)
            .height(120.dp)
            .clickable {},
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            if (city.isSteals) {
                Text(
                    text = "🔥",
                    fontSize = 16.sp
                )
            }

            Text(
                text = city.city,
                style = MaterialTheme.typography.titleSmall.copy(
                    fontWeight = FontWeight.Bold,
                    textAlign = TextAlign.Center
                )
            )

            Text(
                text = city.code,
                style = MaterialTheme.typography.bodySmall.copy(
                    color = DarkGray
                )
            )

            Text(
                text = "$${city.price.toInt()}",
                style = MaterialTheme.typography.labelLarge.copy(
                    fontWeight = FontWeight.Bold,
                    color = PrimaryBlue
                )
            )
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun HomeScreenPreview() {
    val sampleProfile = UserProfile(
        firstName = "Sarah",
        lastName = "Chen",
        birthYear = 1992
    )
    val navController = rememberNavController()
    HomeScreen(navController = navController, profile = sampleProfile)
}
