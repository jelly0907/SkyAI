package com.skyai.app.ui.profile

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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
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
import com.skyai.app.data.model.AgeBucket
import com.skyai.app.data.model.BudgetSensitivity
import com.skyai.app.data.model.DepartureWindow
import com.skyai.app.data.model.JobCategory
import com.skyai.app.data.model.UserProfile

private val PrimaryBlue = Color(0xFF1A3C6B)
private val AccentOrange = Color(0xFFFF6B35)
private val GreenSuccess = Color(0xFF00A651)
private val LightGray = Color(0xFFF8F9FA)
private val DarkGray = Color(0xFF49454E)
private val RedError = Color(0xFFB3261E)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProfileScreen(navController: NavController, profile: UserProfile) {
    var showResetDialog by remember { mutableStateOf(false) }

    if (showResetDialog) {
        AlertDialog(
            onDismissRequest = { showResetDialog = false },
            title = {
                Text(
                    text = "Reset All Personalization?",
                    style = MaterialTheme.typography.headlineSmall.copy(
                        fontWeight = FontWeight.Bold
                    )
                )
            },
            text = {
                Text(
                    text = "This will remove all your travel preferences, watchlists, and personal data stored on this device. This action cannot be undone.",
                    style = MaterialTheme.typography.bodyMedium
                )
            },
            dismissButton = {
                TextButton(onClick = { showResetDialog = false }) {
                    Text("Cancel", color = PrimaryBlue)
                }
            },
            confirmButton = {
                TextButton(
                    onClick = { showResetDialog = false },
                    modifier = Modifier.background(
                        color = RedError.copy(alpha = 0.1f),
                        shape = RoundedCornerShape(4.dp)
                    )
                ) {
                    Text("Reset", color = RedError, fontWeight = FontWeight.Bold)
                }
            }
        )
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Profile",
                        style = MaterialTheme.typography.headlineSmall.copy(
                            fontWeight = FontWeight.Bold
                        )
                    )
                },
                actions = {
                    TextButton(onClick = { navController.navigate("onboarding") }) {
                        Text("Edit", color = PrimaryBlue, fontWeight = FontWeight.Bold)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.White,
                    titleContentColor = PrimaryBlue
                )
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .background(Color.White)
                .verticalScroll(rememberScrollState())
        ) {
            // Avatar and Name Section
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                // Avatar
                Box(
                    modifier = Modifier
                        .size(88.dp)
                        .background(color = PrimaryBlue, shape = CircleShape),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "${profile.firstName.firstOrNull()?.uppercaseChar() ?: 'T'}${profile.lastName.firstOrNull()?.uppercaseChar() ?: 'T'}",
                        style = MaterialTheme.typography.headlineMedium.copy(
                            color = Color.White,
                            fontWeight = FontWeight.Bold
                        )
                    )
                }

                Spacer(modifier = Modifier.height(12.dp))

                Text(
                    text = profile.fullName.ifEmpty { "Traveler" },
                    style = MaterialTheme.typography.headlineSmall.copy(
                        fontWeight = FontWeight.Bold
                    )
                )

                Text(
                    text = profile.jobCategory.displayName,
                    style = MaterialTheme.typography.bodyMedium.copy(
                        color = DarkGray
                    )
                )
            }

            // Traveler Profile Card
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
                    .padding(bottom = 16.dp),
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = LightGray),
                elevation = CardDefaults.cardElevation(defaultElevation = 0.dp)
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.Center,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = profile.budgetSensitivity.emoji,
                            fontSize = 24.sp,
                            modifier = Modifier.padding(end = 8.dp)
                        )
                        Column {
                            Text(
                                text = "Your Traveler Profile",
                                style = MaterialTheme.typography.labelSmall.copy(
                                    color = DarkGray
                                )
                            )
                            Text(
                                text = profile.travelerTypeLabel,
                                style = MaterialTheme.typography.titleMedium.copy(
                                    fontWeight = FontWeight.Bold
                                )
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(16.dp))

                    // Profile dimensions grid
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        ProfileDimensionCell(
                            label = "Budget",
                            value = profile.budgetSensitivity.displayName,
                            modifier = Modifier.weight(1f)
                        )
                        ProfileDimensionCell(
                            label = "Travel Style",
                            value = if (profile.directFlightsPreferred) "Direct" else "Flexible",
                            modifier = Modifier.weight(1f)
                        )
                    }

                    Spacer(modifier = Modifier.height(8.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        ProfileDimensionCell(
                            label = "Loyalty",
                            value = "${profile.loyaltyPrograms.size} Programs",
                            modifier = Modifier.weight(1f)
                        )
                        ProfileDimensionCell(
                            label = "Age Group",
                            value = profile.ageBucket.label,
                            modifier = Modifier.weight(1f)
                        )
                    }
                }
            }

            // Personal Info Section
            SectionCard(
                title = "Personal Info"
            ) {
                ProfileRow(label = "Full Name", value = profile.fullName.ifEmpty { "—" })
                ProfileRow(label = "Age Group", value = profile.ageBucket.label)
                ProfileRow(label = "Occupation", value = profile.jobCategory.displayName)
                ProfileRow(
                    label = "Work Travel",
                    value = if (profile.isFrequentBusinessTraveler) "Yes" else "No"
                )
            }

            // Travel Style Section
            SectionCard(
                title = "Travel Style"
            ) {
                ProfileRow(
                    label = "Priority",
                    value = profile.budgetSensitivity.displayName
                )
                ProfileRow(
                    label = "Departure Times",
                    value = profile.preferredDepartureWindows.joinToString(", ") { it.displayName }
                        .ifEmpty { "—" }
                )
                ProfileRow(
                    label = "Max Layover",
                    value = "${profile.maxLayoverHours}h"
                )
                ProfileRow(
                    label = "Direct Preferred",
                    value = if (profile.directFlightsPreferred) "Yes" else "No"
                )
            }

            // Memberships Section
            SectionCard(
                title = "Memberships"
            ) {
                if (profile.loyaltyPrograms.isEmpty()) {
                    Text(
                        text = "No programs added",
                        style = MaterialTheme.typography.bodyMedium.copy(
                            color = DarkGray
                        ),
                        modifier = Modifier.padding(vertical = 12.dp)
                    )
                } else {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        profile.loyaltyPrograms.forEach { program ->
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(12.dp)
                            ) {
                                Surface(
                                    modifier = Modifier
                                        .background(
                                            color = PrimaryBlue,
                                            shape = RoundedCornerShape(6.dp)
                                        ),
                                    color = PrimaryBlue
                                ) {
                                    Text(
                                        text = program.airlineCode,
                                        style = MaterialTheme.typography.labelSmall.copy(
                                            color = Color.White,
                                            fontWeight = FontWeight.Bold
                                        ),
                                        modifier = Modifier.padding(6.dp)
                                    )
                                }
                                Column {
                                    Text(
                                        text = program.programName,
                                        style = MaterialTheme.typography.bodyMedium.copy(
                                            fontWeight = FontWeight.Bold
                                        )
                                    )
                                    Text(
                                        text = program.tier.displayName,
                                        style = MaterialTheme.typography.bodySmall.copy(
                                            color = DarkGray
                                        )
                                    )
                                }
                            }
                        }
                    }
                }
            }

            // Privacy & Data Section
            SectionCard(
                title = "Privacy & Data"
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 12.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Shield,
                            contentDescription = "Privacy",
                            tint = GreenSuccess,
                            modifier = Modifier.size(20.dp)
                        )
                        Text(
                            text = "Data stored on-device only",
                            style = MaterialTheme.typography.bodyMedium
                        )
                    }
                    Text(
                        text = "✓",
                        style = MaterialTheme.typography.titleLarge.copy(
                            color = GreenSuccess,
                            fontWeight = FontWeight.Bold
                        )
                    )
                }

                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { showResetDialog = true }
                        .padding(vertical = 12.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Reset all personalization",
                        style = MaterialTheme.typography.bodyMedium.copy(
                            color = RedError,
                            fontWeight = FontWeight.SemiBold
                        )
                    )
                    Text(
                        text = "→",
                        style = MaterialTheme.typography.titleMedium.copy(
                            color = RedError
                        )
                    )
                }
            }

            Spacer(modifier = Modifier.height(24.dp))
        }
    }
}

@Composable
private fun ProfileDimensionCell(
    label: String,
    value: String,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .background(Color.White, shape = RoundedCornerShape(12.dp))
            .padding(12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall.copy(
                color = DarkGray
            )
        )
        Text(
            text = value,
            style = MaterialTheme.typography.labelLarge.copy(
                fontWeight = FontWeight.Bold,
                color = PrimaryBlue
            ),
            textAlign = TextAlign.Center
        )
    }
}

@Composable
private fun SectionCard(
    title: String,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .padding(bottom = 16.dp)
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.titleMedium.copy(
                fontWeight = FontWeight.Bold
            ),
            modifier = Modifier.padding(bottom = 12.dp)
        )

        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = Color.White),
            elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
        ) {
            Column(
                modifier = Modifier.padding(16.dp)
            ) {
                content()
            }
        }
    }
}

@Composable
private fun ProfileRow(
    label: String,
    value: String
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodyMedium.copy(
                color = DarkGray
            )
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodyMedium.copy(
                fontWeight = FontWeight.SemiBold,
                color = PrimaryBlue
            )
        )
    }
}

@Preview(showBackground = true)
@Composable
private fun ProfileScreenPreview() {
    val sampleProfile = UserProfile(
        firstName = "Sarah",
        lastName = "Chen",
        birthYear = 1992,
        jobCategory = JobCategory.PROFESSIONAL_OFFICE,
        budgetSensitivity = BudgetSensitivity.BALANCED,
        preferredDepartureWindows = listOf(DepartureWindow.MORNING),
        isFrequentBusinessTraveler = false
    )
    val navController = rememberNavController()
    ProfileScreen(navController = navController, profile = sampleProfile)
}
