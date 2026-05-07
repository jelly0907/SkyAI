package com.skyai.app.ui.search

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import com.skyai.app.data.model.CabinClass
import com.skyai.app.data.model.SearchResponse
import com.skyai.app.data.model.TripType
import com.skyai.app.data.repository.SearchResultsCache
import com.skyai.app.ui.theme.SkyAITheme
import android.app.DatePickerDialog
import java.util.Calendar

@Composable
fun SearchScreen(
    viewModel: SearchViewModel,
    navController: NavController,
    modifier: Modifier = Modifier
) {
    val formState by viewModel.formState.collectAsState()
    val intentParseState by viewModel.intentParseState.collectAsState()
    val searchState by viewModel.searchState.collectAsState()

    LaunchedEffect(searchState) {
        when (searchState) {
            is SearchState.Success -> {
                // Stash the response in process-scoped state and navigate by
                // query_id only. Encoding a 50-offer SearchResponse as JSON
                // and stuffing it into the route string blew past Android's
                // nav-arg size limit and produced a blank Results screen.
                val response = (searchState as SearchState.Success).response
                SearchResultsCache.put(response)
                navController.navigate("results/${response.queryId}")
            }
            else -> {}
        }
    }

    Surface(
        modifier = modifier.fillMaxSize(),
        color = MaterialTheme.colorScheme.background
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Header
            Text(
                text = "SkyAI Flight Finder",
                style = MaterialTheme.typography.headlineLarge,
                modifier = Modifier.padding(vertical = 8.dp)
            )

            // Query TextField
            TextField(
                value = formState.query,
                onValueChange = { viewModel.onQueryChanged(it) },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp),
                label = { Text("Where do you want to go?") },
                trailingIcon = {
                    Icon(
                        imageVector = Icons.Default.Mic,
                        contentDescription = "Voice search",
                        tint = MaterialTheme.colorScheme.primary
                    )
                },
                singleLine = true
            )

            // Interpretation Card
            AnimatedVisibility(
                visible = intentParseState is IntentParseState.Success,
                enter = slideInVertically()
            ) {
                if (intentParseState is IntentParseState.Success) {
                    val response = (intentParseState as IntentParseState.Success).response
                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(4.dp)
                    ) {
                        Column(
                            modifier = Modifier.padding(12.dp),
                            verticalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            Text(
                                text = "Understood your search",
                                style = MaterialTheme.typography.bodyMedium
                            )
                            Text(
                                text = response.interpretation,
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            Text(
                                text = "Confidence: ${(response.confidence * 100).toInt()}%",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.primary
                            )
                        }
                    }
                }
            }

            // Structured Form Toggle
            OutlinedButton(
                onClick = { viewModel.toggleStructuredForm() },
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(if (formState.showStructuredForm) "Hide Details" else "Show Details")
            }

            // Structured Form
            AnimatedVisibility(
                visible = formState.showStructuredForm,
                modifier = Modifier.animateContentSize()
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(
                            MaterialTheme.colorScheme.surfaceVariant,
                            shape = MaterialTheme.shapes.medium
                        )
                        .padding(12.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    // Origin & Destination
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        OutlinedTextField(
                            value = formState.origin,
                            onValueChange = { viewModel.updateOrigin(it.uppercase()) },
                            modifier = Modifier.weight(1f),
                            label = { Text("From") },
                            singleLine = true
                        )
                        OutlinedTextField(
                            value = formState.destination,
                            onValueChange = { viewModel.updateDestination(it.uppercase()) },
                            modifier = Modifier.weight(1f),
                            label = { Text("To") },
                            singleLine = true
                        )
                    }

                    // Dates
                    val context = LocalContext.current
                    val calendar = Calendar.getInstance()

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        OutlinedTextField(
                            value = formState.departureDate,
                            onValueChange = {},
                            modifier = Modifier
                                .weight(1f)
                                .clickableNoRipple {
                                    val picker = DatePickerDialog(
                                        context,
                                        { _, year, month, dayOfMonth ->
                                            val date = String.format(
                                                "%04d-%02d-%02d",
                                                year,
                                                month + 1,
                                                dayOfMonth
                                            )
                                            viewModel.updateDepartureDate(date)
                                        },
                                        calendar.get(Calendar.YEAR),
                                        calendar.get(Calendar.MONTH),
                                        calendar.get(Calendar.DAY_OF_MONTH)
                                    )
                                    picker.show()
                                },
                            label = { Text("Depart") },
                            readOnly = true,
                            singleLine = true
                        )

                        if (formState.tripType == TripType.ROUNDTRIP) {
                            OutlinedTextField(
                                value = formState.returnDate,
                                onValueChange = {},
                                modifier = Modifier
                                    .weight(1f)
                                    .clickableNoRipple {
                                        val picker = DatePickerDialog(
                                            context,
                                            { _, year, month, dayOfMonth ->
                                                val date = String.format(
                                                    "%04d-%02d-%02d",
                                                    year,
                                                    month + 1,
                                                    dayOfMonth
                                                )
                                                viewModel.updateReturnDate(date)
                                            },
                                            calendar.get(Calendar.YEAR),
                                            calendar.get(Calendar.MONTH),
                                            calendar.get(Calendar.DAY_OF_MONTH)
                                        )
                                        picker.show()
                                    },
                                label = { Text("Return") },
                                readOnly = true,
                                singleLine = true
                            )
                        }
                    }

                    // Trip Type Tabs
                    TabRow(
                        selectedTabIndex = if (formState.tripType == TripType.ROUNDTRIP) 0 else 1,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Tab(
                            selected = formState.tripType == TripType.ROUNDTRIP,
                            onClick = { viewModel.updateTripType(TripType.ROUNDTRIP) },
                            text = { Text("Roundtrip") }
                        )
                        Tab(
                            selected = formState.tripType == TripType.ONE_WAY,
                            onClick = { viewModel.updateTripType(TripType.ONE_WAY) },
                            text = { Text("One-way") }
                        )
                    }

                    // Passengers
                    Text(
                        text = "Passengers",
                        style = MaterialTheme.typography.labelLarge
                    )
                    PassengerCounter(
                        label = "Adults",
                        count = formState.adults,
                        onCountChange = { viewModel.updateAdults(it) }
                    )
                    PassengerCounter(
                        label = "Children",
                        count = formState.children,
                        onCountChange = { viewModel.updateChildren(it) }
                    )
                    PassengerCounter(
                        label = "Infants",
                        count = formState.infants,
                        onCountChange = { viewModel.updateInfants(it) }
                    )

                    // Cabin Class Dropdown
                    CabinClassDropdown(
                        selected = formState.cabinClass,
                        onSelect = { viewModel.updateCabinClass(it) }
                    )

                    // Direct Only Switch
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 8.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("Direct flights only")
                        Switch(
                            checked = formState.directOnly,
                            onCheckedChange = { viewModel.updateDirectOnly(it) }
                        )
                    }
                }
            }

            // Error Message
            if (intentParseState is IntentParseState.Error) {
                Text(
                    text = (intentParseState as IntentParseState.Error).message,
                    color = MaterialTheme.colorScheme.error,
                    style = MaterialTheme.typography.bodySmall
                )
            }

            if (searchState is SearchState.Error) {
                Text(
                    text = (searchState as SearchState.Error).message,
                    color = MaterialTheme.colorScheme.error,
                    style = MaterialTheme.typography.bodySmall
                )
            }

            Spacer(modifier = Modifier.height(8.dp))

            // Search Button
            Button(
                onClick = {
                    viewModel.parseIntent()
                    viewModel.searchFlights()
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(48.dp),
                enabled = searchState !is SearchState.Loading && intentParseState !is IntentParseState.Loading
            ) {
                if (searchState is SearchState.Loading || intentParseState is IntentParseState.Loading) {
                    CircularProgressIndicator(
                        modifier = Modifier
                            .width(20.dp)
                            .height(20.dp),
                        color = MaterialTheme.colorScheme.onPrimary,
                        strokeWidth = 2.dp
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                }
                Text("Search Flights")
            }
        }
    }
}

@Composable
private fun PassengerCounter(
    label: String,
    count: Int,
    onCountChange: (Int) -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(label, style = MaterialTheme.typography.bodyMedium)
        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            OutlinedButton(
                onClick = { onCountChange(count - 1) },
                modifier = Modifier
                    .width(36.dp)
                    .height(36.dp),
                enabled = count > 0
            ) {
                Text("−")
            }
            Text(
                text = count.toString(),
                modifier = Modifier.width(24.dp),
                style = MaterialTheme.typography.bodyMedium
            )
            OutlinedButton(
                onClick = { onCountChange(count + 1) },
                modifier = Modifier
                    .width(36.dp)
                    .height(36.dp),
                enabled = count < 9
            ) {
                Text("+")
            }
        }
    }
}

@Composable
private fun CabinClassDropdown(
    selected: CabinClass,
    onSelect: (CabinClass) -> Unit,
    modifier: Modifier = Modifier
) {
    var expanded by remember { mutableStateOf(false) }

    ExposedDropdownMenuBox(
        expanded = expanded,
        onExpandedChange = { expanded = !expanded },
        modifier = modifier.fillMaxWidth()
    ) {
        OutlinedTextField(
            value = selected.name.replace("_", " "),
            onValueChange = {},
            readOnly = true,
            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
            modifier = Modifier
                .menuAnchor()
                .fillMaxWidth(),
            label = { Text("Cabin Class") }
        )
        ExposedDropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false }
        ) {
            CabinClass.entries.forEach { cabinClass ->
                androidx.compose.material3.DropdownMenuItem(
                    text = { Text(cabinClass.name.replace("_", " ")) },
                    onClick = {
                        onSelect(cabinClass)
                        expanded = false
                    }
                )
            }
        }
    }
}

// Helper used by tap-able areas that should NOT show a ripple. `clickable`
// is a Modifier extension (in androidx.compose.foundation), so it needs a
// Modifier receiver — calling it as a free function fails to resolve.
// `composed { ... }` (also a Modifier extension) defers construction into a
// composable scope so `remember { MutableInteractionSource() }` can run.
private fun Modifier.clickableNoRipple(onClick: () -> Unit): Modifier =
    composed {
        val interactionSource = remember { MutableInteractionSource() }
        this.clickable(
            indication = null,
            interactionSource = interactionSource,
            onClick = onClick
        )
    }

@Preview(showBackground = true)
@Composable
fun SearchScreenPreview() {
    SkyAITheme {
        // Preview would need a mock ViewModel and NavController
    }
}
