package com.skyai.app.ui.watchlist

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Divider
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavController
import androidx.navigation.compose.rememberNavController
import com.skyai.app.data.model.PriceWatch
import com.skyai.app.data.model.PriceTrend
import com.skyai.app.data.model.WatchStatus
import kotlinx.coroutines.launch

private val PrimaryBlue = Color(0xFF1A3C6B)
private val AccentOrange = Color(0xFFFF6B35)
private val GreenSuccess = Color(0xFF00A651)
private val LightGray = Color(0xFFF8F9FA)
private val DarkGray = Color(0xFF49454E)
private val RedError = Color(0xFFB3261E)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WatchlistScreen(navController: NavController) {
    val snackbarHostState = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()

    val sampleWatches = listOf(
        PriceWatch(
            origin = "SFO",
            destination = "NRT",
            originCity = "San Francisco",
            destinationCity = "Tokyo",
            departureRange = "Jul 2026",
            currentBestPrice = 842.0,
            alertThreshold = 800.0,
            predictedLow = 788.0,
            priceAtCreation = 1020.0,
            trend = PriceTrend.UP,
            status = WatchStatus.ACTIVE,
            airline = "NH"
        ),
        PriceWatch(
            origin = "SFO",
            destination = "LHR",
            originCity = "San Francisco",
            destinationCity = "London",
            departureRange = "Aug 5–15",
            currentBestPrice = 1120.0,
            alertThreshold = 950.0,
            predictedLow = 910.0,
            priceAtCreation = 1200.0,
            trend = PriceTrend.DOWN,
            status = WatchStatus.ACTIVE,
            airline = "BA"
        )
    )

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Watchlist",
                        style = MaterialTheme.typography.headlineSmall.copy(
                            fontWeight = FontWeight.Bold
                        )
                    )
                },
                actions = {
                    IconButton(
                        onClick = {
                            scope.launch {
                                snackbarHostState.showSnackbar("Coming soon!")
                            }
                        }
                    ) {
                        Icon(
                            imageVector = Icons.Default.Add,
                            contentDescription = "Add watch",
                            tint = PrimaryBlue
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.White,
                    titleContentColor = PrimaryBlue
                )
            )
        },
        snackbarHost = { SnackbarHost(hostState = snackbarHostState) }
    ) { padding ->
        if (sampleWatches.isEmpty()) {
            EmptyWatchlistState(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
            )
        } else {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .background(Color.White),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(
                    horizontal = 16.dp,
                    vertical = 12.dp
                ),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                items(sampleWatches) { watch ->
                    WatchCard(watch = watch)
                }
            }
        }
    }
}

@Composable
private fun WatchCard(watch: PriceWatch) {
    var isMenuExpanded by remember { mutableStateOf(false) }

    Card(
        modifier = Modifier
            .fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            // Header row
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 8.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = "${watch.origin} → ${watch.destination}",
                        style = MaterialTheme.typography.titleMedium.copy(
                            fontWeight = FontWeight.Bold
                        )
                    )
                    Text(
                        text = "${watch.destinationCity} · ${watch.departureRange}",
                        style = MaterialTheme.typography.bodySmall.copy(
                            color = DarkGray
                        )
                    )
                }

                // Status chip
                Surface(
                    modifier = Modifier.background(
                        color = GreenSuccess.copy(alpha = 0.15f),
                        shape = RoundedCornerShape(8.dp)
                    ),
                    color = GreenSuccess.copy(alpha = 0.15f)
                ) {
                    Text(
                        text = "● ${watch.status.name}",
                        style = MaterialTheme.typography.labelSmall.copy(
                            color = GreenSuccess,
                            fontWeight = FontWeight.Bold
                        ),
                        modifier = Modifier.padding(6.dp)
                    )
                }

                Box {
                    IconButton(
                        onClick = { isMenuExpanded = true },
                        modifier = Modifier.size(24.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.MoreVert,
                            contentDescription = "Menu",
                            tint = DarkGray,
                            modifier = Modifier.size(20.dp)
                        )
                    }
                    DropdownMenu(
                        expanded = isMenuExpanded,
                        onDismissRequest = { isMenuExpanded = false }
                    ) {
                        DropdownMenuItem(
                            text = { Text("Pause") },
                            onClick = { isMenuExpanded = false }
                        )
                        DropdownMenuItem(
                            text = { Text("Remove") },
                            onClick = { isMenuExpanded = false }
                        )
                    }
                }
            }

            Divider(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 12.dp),
                color = LightGray
            )

            // Price row
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 4.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.Top
            ) {
                Column {
                    Text(
                        text = "Current best",
                        style = MaterialTheme.typography.labelSmall.copy(
                            color = DarkGray
                        )
                    )
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        Text(
                            text = "$${watch.currentBestPrice.toInt()}",
                            style = MaterialTheme.typography.titleLarge.copy(
                                fontWeight = FontWeight.Bold,
                                color = PrimaryBlue
                            )
                        )
                        // Trend badge
                        Surface(
                            modifier = Modifier.background(
                                color = if (watch.trend == PriceTrend.DOWN) GreenSuccess.copy(alpha = 0.15f)
                                else RedError.copy(alpha = 0.15f),
                                shape = RoundedCornerShape(6.dp)
                            ),
                            color = if (watch.trend == PriceTrend.DOWN) GreenSuccess.copy(alpha = 0.15f)
                            else RedError.copy(alpha = 0.15f)
                        ) {
                            Text(
                                text = if (watch.trend == PriceTrend.DOWN) "↓ FALLING" else "↑ RISING",
                                style = MaterialTheme.typography.labelSmall.copy(
                                    color = if (watch.trend == PriceTrend.DOWN) GreenSuccess else RedError,
                                    fontWeight = FontWeight.Bold
                                ),
                                modifier = Modifier.padding(4.dp)
                            )
                        }
                    }
                }

                Column(horizontalAlignment = Alignment.End) {
                    Text(
                        text = "Alert when",
                        style = MaterialTheme.typography.labelSmall.copy(
                            color = DarkGray
                        )
                    )
                    Text(
                        text = "$${watch.alertThreshold.toInt()}",
                        style = MaterialTheme.typography.titleMedium.copy(
                            fontWeight = FontWeight.Bold,
                            color = AccentOrange
                        )
                    )
                    if (watch.predictedLow != null) {
                        Text(
                            text = "Predicted low: $${watch.predictedLow.toInt()}",
                            style = MaterialTheme.typography.labelSmall.copy(
                                color = GreenSuccess,
                                fontWeight = FontWeight.Bold
                            )
                        )
                    }
                }
            }

            // Trend info box (shown when FALLING)
            if (watch.trend == PriceTrend.DOWN) {
                Spacer(modifier = Modifier.height(12.dp))
                Surface(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(
                            color = GreenSuccess.copy(alpha = 0.1f),
                            shape = RoundedCornerShape(8.dp)
                        ),
                    color = GreenSuccess.copy(alpha = 0.1f)
                ) {
                    Text(
                        text = "📉 Trending down — expected to hit target in ~12 days",
                        style = MaterialTheme.typography.bodySmall.copy(
                            color = GreenSuccess,
                            fontWeight = FontWeight.SemiBold
                        ),
                        modifier = Modifier.padding(12.dp)
                    )
                }
            }
        }
    }
}

@Composable
private fun EmptyWatchlistState(modifier: Modifier = Modifier) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = "🔔",
            fontSize = 64.sp,
            modifier = Modifier.padding(bottom = 16.dp)
        )
        Text(
            text = "No Price Watches Yet",
            style = MaterialTheme.typography.headlineSmall.copy(
                fontWeight = FontWeight.Bold
            ),
            modifier = Modifier.padding(bottom = 8.dp)
        )
        Text(
            text = "Track prices for your favorite routes and get notified when prices drop",
            style = MaterialTheme.typography.bodyMedium.copy(
                color = DarkGray,
                textAlign = TextAlign.Center
            ),
            modifier = Modifier
                .padding(bottom = 24.dp)
                .padding(horizontal = 32.dp)
        )
        androidx.compose.material3.OutlinedButton(
            onClick = {}
        ) {
            Text(
                text = "Watch a Route",
                color = PrimaryBlue
            )
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun WatchlistScreenPreview() {
    val navController = rememberNavController()
    WatchlistScreen(navController = navController)
}

@Preview(showBackground = true)
@Composable
private fun WatchlistEmptyPreview() {
    Surface(modifier = Modifier.fillMaxSize()) {
        EmptyWatchlistState()
    }
}
