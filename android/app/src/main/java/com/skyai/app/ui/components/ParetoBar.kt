package com.skyai.app.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccessTime
import androidx.compose.material.icons.filled.LocalOffer
import androidx.compose.material.icons.filled.TrendingDown
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.skyai.app.data.model.FlightOffer
import com.skyai.app.ui.theme.SkyAITheme

@Composable
fun ParetoBar(
    offers: List<FlightOffer>,
    onSelectCheapest: () -> Unit,
    onSelectFastest: () -> Unit,
    onSelectBestDeal: () -> Unit,
    modifier: Modifier = Modifier
) {
    if (offers.isEmpty()) return

    val cheapest = offers.minByOrNull { it.price.total }
    val fastest = offers.minByOrNull { it.outboundItinerary.totalDurationMinutes }
    val bestDeal = offers.maxByOrNull { it.priceIntelligence.percentile }

    Surface(
        modifier = modifier
            .fillMaxWidth()
            .height(64.dp),
        color = MaterialTheme.colorScheme.surface,
        shadowElevation = 8.dp
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 8.dp, vertical = 4.dp),
            horizontalArrangement = Arrangement.spacedBy(4.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            if (cheapest != null) {
                FilterChip(
                    selected = false,
                    onClick = onSelectCheapest,
                    label = {
                        Text(
                            text = "$${String.format("%.0f", cheapest.price.total)}",
                            fontSize = 11.sp
                        )
                    },
                    leadingIcon = {
                        Icon(
                            imageVector = Icons.Default.LocalOffer,
                            contentDescription = "Cheapest",
                            modifier = Modifier
                                .android.compose.ui.unit.sp(16)
                        )
                    },
                    modifier = Modifier.weight(1f)
                )
            }

            if (fastest != null) {
                FilterChip(
                    selected = false,
                    onClick = onSelectFastest,
                    label = {
                        Text(
                            text = formatDuration(fastest.outboundItinerary.totalDurationMinutes),
                            fontSize = 11.sp
                        )
                    },
                    leadingIcon = {
                        Icon(
                            imageVector = Icons.Default.AccessTime,
                            contentDescription = "Fastest",
                            modifier = Modifier
                                .android.compose.ui.unit.sp(16)
                        )
                    },
                    modifier = Modifier.weight(1f)
                )
            }

            if (bestDeal != null) {
                FilterChip(
                    selected = false,
                    onClick = onSelectBestDeal,
                    label = {
                        Text(
                            text = "Best Deal",
                            fontSize = 11.sp
                        )
                    },
                    leadingIcon = {
                        Icon(
                            imageVector = Icons.Default.TrendingDown,
                            contentDescription = "Best Deal",
                            modifier = Modifier
                                .android.compose.ui.unit.sp(16)
                        )
                    },
                    modifier = Modifier.weight(1f)
                )
            }
        }
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
fun ParetoBarPreview() {
    SkyAITheme {
        // Preview would require mock data
    }
}
