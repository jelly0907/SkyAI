package com.skyai.app.ui.detail

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.AirlineSeatReclineExtra
import androidx.compose.material.icons.filled.ArrowForward
import androidx.compose.material.icons.filled.BackpackRounded
import androidx.compose.material.icons.filled.BellOutlined
import androidx.compose.material.icons.filled.RestartAlt
import androidx.compose.material.icons.filled.TrendingDown
import androidx.compose.material.icons.filled.TrendingUp
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavController
import com.skyai.app.data.model.ActionType
import com.skyai.app.data.model.FlightOffer
import com.skyai.app.data.model.PriceLabel
import com.skyai.app.data.model.PriceTrend
import com.skyai.app.ui.theme.SkyAITheme
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

@Composable
fun FlightDetailScreen(
    navController: NavController,
    offer: FlightOffer,
    modifier: Modifier = Modifier
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Flight Details",
                        style = MaterialTheme.typography.titleMedium
                    )
                },
                navigationIcon = {
                    IconButton(onClick = { navController.popBackStack() }) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Back"
                        )
                    }
                }
            )
        },
        modifier = modifier.fillMaxSize()
    ) { paddingValues ->
        Surface(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues),
            color = MaterialTheme.colorScheme.background
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                // Airline Header
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Text(
                            text = "${offer.outboundItinerary.segments.first().airline} ${offer.outboundItinerary.segments.first().flightNumber}",
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.Bold
                        )
                        Text(
                            text = "Fare Class: ${offer.fareClass}",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }

                // Route Card
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        Text(
                            text = "Outbound Flight",
                            style = MaterialTheme.typography.titleSmall,
                            fontWeight = FontWeight.Bold
                        )
                        offer.outboundItinerary.segments.forEachIndexed { index, segment ->
                            SegmentRow(segment = segment)
                            if (index < offer.outboundItinerary.segments.size - 1) {
                                Text(
                                    text = "Connection Time",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    modifier = Modifier.padding(start = 16.dp)
                                )
                            }
                        }
                    }
                }

                // Return Flight (if roundtrip)
                if (offer.returnItinerary != null) {
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
                    ) {
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(16.dp),
                            verticalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            Text(
                                text = "Return Flight",
                                style = MaterialTheme.typography.titleSmall,
                                fontWeight = FontWeight.Bold
                            )
                            offer.returnItinerary.segments.forEachIndexed { index, segment ->
                                SegmentRow(segment = segment)
                                if (index < offer.returnItinerary.segments.size - 1) {
                                    Text(
                                        text = "Connection Time",
                                        style = MaterialTheme.typography.labelSmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                        modifier = Modifier.padding(start = 16.dp)
                                    )
                                }
                            }
                        }
                    }
                }

                // Price Intelligence Card
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        Text(
                            text = "Price Intelligence",
                            style = MaterialTheme.typography.titleSmall,
                            fontWeight = FontWeight.Bold
                        )

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = "$${String.format("%.2f", offer.price.total)}",
                                style = MaterialTheme.typography.displaySmall,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.primary
                            )

                            if (offer.priceIntelligence.priceLabel != PriceLabel.UNKNOWN) {
                                Surface(
                                    modifier = Modifier.padding(8.dp),
                                    color = when (offer.priceIntelligence.priceLabel) {
                                        PriceLabel.STEAL -> Color(0xFFEF5350)
                                        PriceLabel.GREAT_DEAL -> Color(0xFF66BB6A)
                                        PriceLabel.FAIR -> Color(0xFF90A4AE)
                                        PriceLabel.EXPENSIVE -> Color(0xFFF59E0B)
                                        PriceLabel.OVERPRICED -> Color(0xFFEF4444)
                                        PriceLabel.UNKNOWN -> Color.Transparent
                                    },
                                    shape = MaterialTheme.shapes.small
                                ) {
                                    Text(
                                        text = when (offer.priceIntelligence.priceLabel) {
                                            PriceLabel.STEAL -> "STEAL"
                                            PriceLabel.GREAT_DEAL -> "GREAT DEAL"
                                            PriceLabel.FAIR -> "FAIR"
                                            PriceLabel.EXPENSIVE -> "ABOVE AVG"
                                            PriceLabel.OVERPRICED -> "OVERPRICED"
                                            PriceLabel.UNKNOWN -> ""
                                        },
                                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                                        style = MaterialTheme.typography.labelSmall,
                                        color = Color.White,
                                        fontWeight = FontWeight.Bold
                                    )
                                }
                            }
                        }

                        // Percentile Progress
                        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    text = "Percentile",
                                    style = MaterialTheme.typography.labelSmall
                                )
                                Text(
                                    text = "Cheaper than ${offer.priceIntelligence.percentile}% of fares",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                            LinearProgressIndicator(
                                progress = { offer.priceIntelligence.percentile / 100f },
                                modifier = Modifier.fillMaxWidth()
                            )
                        }

                        // Trend
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                imageVector = when (offer.priceIntelligence.trend) {
                                    PriceTrend.RISING -> Icons.Default.TrendingUp
                                    PriceTrend.FALLING -> Icons.Default.TrendingDown
                                    PriceTrend.STABLE -> Icons.Default.RestartAlt
                                    // VOLATILE means "no clear direction" — reuse the
                                    // stable icon; copy below differentiates the wording.
                                    PriceTrend.VOLATILE -> Icons.Default.RestartAlt
                                },
                                contentDescription = null,
                                tint = when (offer.priceIntelligence.trend) {
                                    PriceTrend.RISING -> Color(0xFFEF5350)
                                    PriceTrend.FALLING -> Color(0xFF66BB6A)
                                    PriceTrend.STABLE -> Color(0xFF90A4AE)
                                    PriceTrend.VOLATILE -> Color(0xFFF59E0B)
                                },
                                modifier = Modifier
                                    .width(20.dp)
                                    .height(20.dp)
                            )
                            Text(
                                text = when (offer.priceIntelligence.trend) {
                                    PriceTrend.RISING -> "Price Rising"
                                    PriceTrend.FALLING -> "Price Falling"
                                    PriceTrend.STABLE -> "Price Stable"
                                    PriceTrend.VOLATILE -> "Price Volatile"
                                },
                                style = MaterialTheme.typography.labelSmall
                            )
                        }

                        // Action Reason
                        Text(
                            text = offer.priceIntelligence.actionReason,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )

                        // Price Forecast (if available)
                        if (offer.priceIntelligence.predicted7d != null || offer.priceIntelligence.predicted14d != null) {
                            Column(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(top = 8.dp),
                                verticalArrangement = Arrangement.spacedBy(4.dp)
                            ) {
                                Text(
                                    text = "Price Forecast",
                                    style = MaterialTheme.typography.labelSmall,
                                    fontWeight = FontWeight.Bold
                                )
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                                ) {
                                    if (offer.priceIntelligence.predicted7d != null) {
                                        ForecastBox(
                                            label = "+7 days",
                                            price = offer.priceIntelligence.predicted7d,
                                            modifier = Modifier.weight(1f)
                                        )
                                    }
                                    if (offer.priceIntelligence.predicted14d != null) {
                                        ForecastBox(
                                            label = "+14 days",
                                            price = offer.priceIntelligence.predicted14d,
                                            modifier = Modifier.weight(1f)
                                        )
                                    }
                                }
                            }
                        }
                    }
                }

                // Details Card
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        Text(
                            text = "Flight Details",
                            style = MaterialTheme.typography.titleSmall,
                            fontWeight = FontWeight.Bold
                        )

                        DetailRow(
                            icon = Icons.Default.BackpackRounded,
                            label = "Baggage",
                            value = offer.baggageInfo.checkedBags
                        )

                        DetailRow(
                            icon = Icons.Default.RestartAlt,
                            label = "Changes",
                            value = if (offer.fareConditions.changeable) "Allowed" else "Not Allowed"
                        )

                        DetailRow(
                            icon = Icons.Default.AirlineSeatReclineExtra,
                            label = "Refundable",
                            value = if (offer.fareConditions.refundable) "Yes" else "No"
                        )

                        DetailRow(
                            icon = Icons.Default.AirlineSeatReclineExtra,
                            label = "Seats Remaining",
                            value = offer.seatsRemaining.toString()
                        )
                    }
                }

                Spacer(modifier = Modifier.height(8.dp))

                // Action Buttons
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Button(
                        onClick = { },
                        modifier = Modifier
                            .weight(1f)
                            .height(48.dp)
                    ) {
                        Text("Book Now")
                    }

                    OutlinedButton(
                        onClick = { },
                        modifier = Modifier
                            .weight(1f)
                            .height(48.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.BellOutlined,
                            contentDescription = null,
                            modifier = Modifier
                                .width(18.dp)
                                .height(18.dp)
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("Set Alert")
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))
            }
        }
    }
}

@Composable
private fun SegmentRow(
    segment: com.skyai.app.data.model.Segment,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column {
                Text(
                    text = formatTime(segment.departureTime),
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = segment.departureAirport,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            Icon(
                imageVector = Icons.Default.ArrowForward,
                contentDescription = null,
                modifier = Modifier
                    .width(24.dp)
                    .height(24.dp),
                tint = MaterialTheme.colorScheme.primary
            )

            Column(horizontalAlignment = Alignment.End) {
                Text(
                    text = formatTime(segment.arrivalTime),
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = segment.arrivalAirport,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
        Text(
            text = "${segment.airline} ${segment.flightNumber} • ${segment.aircraft} • ${formatDuration(segment.durationMinutes)}",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun DetailRow(
    icon: ImageVector,
    label: String,
    value: String,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            modifier = Modifier
                .width(24.dp)
                .height(24.dp),
            tint = MaterialTheme.colorScheme.primary
        )
        Column {
            Text(
                text = label,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Text(
                text = value,
                style = MaterialTheme.typography.bodySmall,
                fontWeight = FontWeight.Bold
            )
        }
    }
}

@Composable
private fun ForecastBox(
    label: String,
    price: Double,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(8.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Text(
                text = label,
                style = MaterialTheme.typography.labelSmall
            )
            Text(
                text = "$${String.format("%.2f", price)}",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Bold
            )
        }
    }
}

private fun formatTime(isoString: String): String {
    return try {
        val instant = Instant.parse(isoString)
        instant.atZone(ZoneId.systemDefault()).toLocalTime()
            .format(DateTimeFormatter.ofPattern("HH:mm"))
    } catch (e: Exception) {
        isoString.substring(11, 16)
    }
}

private fun formatDuration(minutes: Int): String {
    val hours = minutes / 60
    val mins = minutes % 60
    return if (hours > 0) {
        "${hours}h ${mins}m"
    } else {
        "${mins}m"
    }
}

@Preview(showBackground = true)
@Composable
fun FlightDetailScreenPreview() {
    SkyAITheme {
        // Preview would require mock data
    }
}
