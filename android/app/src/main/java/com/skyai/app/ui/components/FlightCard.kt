package com.skyai.app.ui.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccessTime
import androidx.compose.material.icons.filled.AirlineSeatReclineExtra
import androidx.compose.material.icons.filled.FlightTakeoff
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.skyai.app.data.model.ActionType
import com.skyai.app.data.model.FlightOffer
import com.skyai.app.data.model.PriceLabel
import com.skyai.app.ui.theme.SkyAITheme
import java.time.LocalTime
import java.time.format.DateTimeFormatter

@Composable
fun FlightCard(
    offer: FlightOffer,
    onSelectFlight: () -> Unit,
    modifier: Modifier = Modifier
) {
    val badgeColor = when (offer.priceIntelligence.priceLabel) {
        PriceLabel.STEAL -> Color(0xFFEF5350)
        PriceLabel.GREAT_DEAL -> Color(0xFF66BB6A)
        PriceLabel.FAIR -> Color(0xFF90A4AE)
        PriceLabel.EXPENSIVE -> Color(0xFFF59E0B)
        PriceLabel.OVERPRICED -> Color(0xFFEF4444)
        PriceLabel.UNKNOWN -> null
    }

    val badgeText = when (offer.priceIntelligence.priceLabel) {
        PriceLabel.STEAL -> "STEAL"
        PriceLabel.GREAT_DEAL -> "GREAT DEAL"
        PriceLabel.FAIR -> "FAIR"
        PriceLabel.EXPENSIVE -> "ABOVE AVG"
        PriceLabel.OVERPRICED -> "OVERPRICED"
        PriceLabel.UNKNOWN -> null
    }

    Card(
        modifier = modifier
            .fillMaxWidth()
            .clickable { onSelectFlight() },
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
        shape = MaterialTheme.shapes.medium
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            // Header with Badge
            Row(
                modifier = Modifier
                    .fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.Top
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = "${offer.outboundItinerary.segments.first().airline} ${offer.outboundItinerary.segments.first().flightNumber}",
                        style = MaterialTheme.typography.labelLarge
                    )
                }
                if (badgeColor != null && badgeText != null) {
                    Surface(
                        modifier = Modifier
                            .background(badgeColor, shape = MaterialTheme.shapes.small)
                            .padding(horizontal = 8.dp, vertical = 4.dp),
                        color = badgeColor,
                        shape = MaterialTheme.shapes.small
                    ) {
                        Text(
                            text = badgeText,
                            style = MaterialTheme.typography.labelSmall,
                            color = Color.White,
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }
            }

            // Route and Times
            val outbound = offer.outboundItinerary
            val firstSegment = outbound.segments.first()
            val lastSegment = outbound.segments.last()

            val departTime = formatTime(firstSegment.departureTime)
            val arriveTime = formatTime(lastSegment.arrivalTime)

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 4.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = departTime,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        text = firstSegment.departureAirport,
                        style = MaterialTheme.typography.labelSmall
                    )
                }

                Column(
                    modifier = Modifier
                        .weight(1f)
                        .padding(horizontal = 8.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(24.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.Center
                    ) {
                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .height(1.dp)
                                .background(MaterialTheme.colorScheme.outline)
                        )
                        repeat(maxOf(1, outbound.segments.size - 1)) {
                            Box(
                                modifier = Modifier
                                    .width(4.dp)
                                    .height(4.dp)
                                    .background(
                                        MaterialTheme.colorScheme.primary,
                                        shape = MaterialTheme.shapes.small
                                    )
                                    .padding(horizontal = 2.dp)
                            )
                        }
                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .height(1.dp)
                                .background(MaterialTheme.colorScheme.outline)
                        )
                    }
                }

                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = arriveTime,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        text = lastSegment.arrivalAirport,
                        style = MaterialTheme.typography.labelSmall
                    )
                }
            }

            // Duration and Stops
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 4.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = Icons.Default.AccessTime,
                        contentDescription = null,
                        modifier = Modifier
                            .width(16.dp)
                            .height(16.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(
                        text = formatDuration(outbound.totalDurationMinutes),
                        style = MaterialTheme.typography.labelSmall
                    )
                }

                val stops = outbound.segments.size - 1
                Text(
                    text = if (stops == 0) "Nonstop" else "$stops stop${if (stops > 1) "s" else ""}",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            Spacer(modifier = Modifier.height(4.dp))

            // Price and Action Button
            Row(
                modifier = Modifier
                    .fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = "$${String.format("%.2f", offer.price.total)}",
                        style = MaterialTheme.typography.headlineSmall,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.primary
                    )
                    if (offer.priceIntelligence.percentile < 100) {
                        Text(
                            text = "Cheaper than ${offer.priceIntelligence.percentile}% of fares",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }

                val actionButtonColor = when (offer.priceIntelligence.actionType) {
                    ActionType.BUY_NOW -> MaterialTheme.colorScheme.primary
                    ActionType.WAIT -> MaterialTheme.colorScheme.secondary
                    ActionType.SET_ALERT -> Color(0xFFFF6B35)
                    ActionType.MONITOR -> MaterialTheme.colorScheme.outline
                }

                when (offer.priceIntelligence.actionType) {
                    ActionType.BUY_NOW -> {
                        Button(
                            onClick = { onSelectFlight() },
                            modifier = Modifier.width(100.dp)
                        ) {
                            Text("Book Now", fontSize = 12.sp)
                        }
                    }

                    ActionType.WAIT -> {
                        OutlinedButton(
                            onClick = { onSelectFlight() },
                            modifier = Modifier.width(100.dp)
                        ) {
                            Text("Watch 📉", fontSize = 12.sp)
                        }
                    }

                    ActionType.SET_ALERT -> {
                        OutlinedButton(
                            onClick = { onSelectFlight() },
                            modifier = Modifier.width(100.dp)
                        ) {
                            Text("Set Alert 🔔", fontSize = 12.sp)
                        }
                    }

                    // MONITOR is the engine's "neutral" recommendation —
                    // price is in line with history. Show the same button
                    // shape as the other passive actions.
                    ActionType.MONITOR -> {
                        OutlinedButton(
                            onClick = { onSelectFlight() },
                            modifier = Modifier.width(100.dp)
                        ) {
                            Text("Monitor 👀", fontSize = 12.sp)
                        }
                    }
                }
            }
        }
    }
}

private fun formatTime(isoString: String): String {
    return try {
        val instant = java.time.Instant.parse(isoString)
        instant.atZone(java.time.ZoneId.systemDefault()).toLocalTime()
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
fun FlightCardPreview() {
    SkyAITheme {
        // Preview would require mock FlightOffer data
    }
}
