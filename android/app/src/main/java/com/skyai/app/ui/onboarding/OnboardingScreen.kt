package com.skyai.app.ui.onboarding

import androidx.compose.animation.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavController
import com.skyai.app.data.model.*

private val PrimaryBlue   = Color(0xFF1A3C6B)
private val AccentOrange  = Color(0xFFFF6B35)
private val SurfaceGray   = Color(0xFFF8F9FA)

@Composable
fun OnboardingScreen(
    navController: NavController,
    onComplete: (UserProfile) -> Unit
) {
    var currentStep by remember { mutableIntStateOf(1) }
    var profile by remember { mutableStateOf(UserProfile()) }
    val totalSteps = 3

    Column(modifier = Modifier.fillMaxSize().background(SurfaceGray)) {

        // ── Progress header ───────────────────────────────────────────────
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(Color.White)
                .padding(horizontal = 24.dp, vertical = 16.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("SkyAI", fontSize = 22.sp, fontWeight = FontWeight.Black, color = PrimaryBlue)
                Text("Step $currentStep of $totalSteps", fontSize = 14.sp, color = Color.Gray)
            }
            Spacer(modifier = Modifier.height(12.dp))
            LinearProgressIndicator(
                progress = { currentStep.toFloat() / totalSteps },
                modifier = Modifier.fillMaxWidth().height(6.dp).clip(RoundedCornerShape(3.dp)),
                color = AccentOrange,
                trackColor = Color(0xFFE5E7EB)
            )
        }

        // ── Step content ──────────────────────────────────────────────────
        Box(modifier = Modifier.weight(1f)) {
            AnimatedContent(
                targetState = currentStep,
                transitionSpec = {
                    (slideInHorizontally { it } + fadeIn()) togetherWith
                    (slideOutHorizontally { -it } + fadeOut())
                },
                label = "step"
            ) { step ->
                when (step) {
                    1 -> Step1PersonalInfo(
                        profile = profile,
                        onUpdate = { profile = it }
                    )
                    2 -> Step2TravelStyle(
                        profile = profile,
                        onUpdate = { profile = it }
                    )
                    3 -> Step3Memberships(
                        profile = profile,
                        onUpdate = { profile = it }
                    )
                }
            }
        }

        // ── Navigation buttons ────────────────────────────────────────────
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(Color.White)
                .padding(horizontal = 24.dp, vertical = 20.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            AnimatedVisibility(visible = currentStep > 1) {
                OutlinedButton(
                    onClick = { currentStep-- },
                    modifier = Modifier.weight(1f).height(52.dp),
                    border = BorderStroke(1.dp, PrimaryBlue)
                ) {
                    Icon(Icons.Default.ChevronLeft, contentDescription = null, tint = PrimaryBlue)
                    Text("Back", color = PrimaryBlue, fontWeight = FontWeight.SemiBold)
                }
            }

            if (currentStep < totalSteps) {
                Button(
                    onClick = { currentStep++ },
                    modifier = Modifier.weight(1f).height(52.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = AccentOrange),
                    shape = RoundedCornerShape(14.dp)
                ) {
                    Text("Continue", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                    Icon(Icons.Default.ChevronRight, contentDescription = null)
                }
            } else {
                Button(
                    onClick = {
                        val completed = profile.copy(isOnboardingComplete = true)
                        onComplete(completed)
                    },
                    modifier = Modifier.weight(1f).height(52.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = AccentOrange),
                    shape = RoundedCornerShape(14.dp)
                ) {
                    Icon(Icons.Default.FlightTakeoff, contentDescription = null)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Let's fly!", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                }
            }
        }
    }
}

// ── Step 1: Personal Info ─────────────────────────────────────────────────────

@Composable
private fun Step1PersonalInfo(profile: UserProfile, onUpdate: (UserProfile) -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(24.dp)
    ) {
        StepHeader(
            title = "Tell us about yourself",
            subtitle = "We use this to surface student discounts, senior fares, and age-appropriate deals."
        )

        // Name
        SectionLabel(icon = "👤", title = "Your Name")
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            OutlinedTextField(
                value = profile.firstName,
                onValueChange = { onUpdate(profile.copy(firstName = it)) },
                label = { Text("First name") },
                modifier = Modifier.weight(1f),
                shape = RoundedCornerShape(12.dp),
                singleLine = true
            )
            OutlinedTextField(
                value = profile.lastName,
                onValueChange = { onUpdate(profile.copy(lastName = it)) },
                label = { Text("Last name") },
                modifier = Modifier.weight(1f),
                shape = RoundedCornerShape(12.dp),
                singleLine = true
            )
        }

        // Birth year
        SectionLabel(icon = "🎂", title = "Birth Year")
        OutlinedTextField(
            value = if (profile.birthYear == 0) "" else profile.birthYear.toString(),
            onValueChange = { onUpdate(profile.copy(birthYear = it.toIntOrNull() ?: profile.birthYear)) },
            label = { Text("Year (e.g. 1995)") },
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp),
            singleLine = true,
            trailingIcon = {
                Surface(
                    color = AccentOrange,
                    shape = RoundedCornerShape(20.dp)
                ) {
                    Text(
                        text = profile.ageBucket.label,
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                        color = Color.White,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
        )

        // Job Category
        SectionLabel(icon = "💼", title = "What do you do?")
        LazyVerticalGrid(
            columns = GridCells.Fixed(2),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.height(200.dp)
        ) {
            items(JobCategory.values()) { job ->
                val selected = profile.jobCategory == job
                Surface(
                    onClick = { onUpdate(profile.copy(jobCategory = job)) },
                    color = if (selected) AccentOrange else Color.White,
                    shape = RoundedCornerShape(12.dp),
                    border = BorderStroke(1.dp, if (selected) AccentOrange else Color(0xFFE5E7EB)),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(
                        modifier = Modifier.padding(12.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Text(text = "💼", fontSize = 20.sp)
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = job.displayName,
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Medium,
                            color = if (selected) Color.White else Color.Black,
                            textAlign = TextAlign.Center
                        )
                    }
                }
            }
        }

        // Work travel toggle
        SectionLabel(icon = "✈️", title = "Work Travel")
        Surface(
            color = Color.White,
            shape = RoundedCornerShape(12.dp),
            border = BorderStroke(1.dp, Color(0xFFE5E7EB)),
            modifier = Modifier.fillMaxWidth()
        ) {
            Row(
                modifier = Modifier.padding(16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text("Travel for work monthly", fontWeight = FontWeight.Medium, fontSize = 15.sp)
                    Text("Frequent business flyer", color = Color.Gray, fontSize = 13.sp)
                }
                Switch(
                    checked = profile.isFrequentBusinessTraveler,
                    onCheckedChange = { onUpdate(profile.copy(isFrequentBusinessTraveler = it)) },
                    colors = SwitchDefaults.colors(checkedThumbColor = AccentOrange, checkedTrackColor = AccentOrange.copy(alpha = 0.4f))
                )
            }
        }

        Spacer(modifier = Modifier.height(8.dp))
    }
}

// ── Step 2: Travel Style ──────────────────────────────────────────────────────

@Composable
private fun Step2TravelStyle(profile: UserProfile, onUpdate: (UserProfile) -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(24.dp)
    ) {
        StepHeader(
            title = "Your travel style",
            subtitle = "We'll rank flights the way YOU want — not just by price."
        )

        // Budget attitude
        SectionLabel(icon = "💳", title = "What matters most?")
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            BudgetSensitivity.values().forEach { option ->
                val selected = profile.budgetSensitivity == option
                Surface(
                    onClick = { onUpdate(profile.copy(budgetSensitivity = option)) },
                    color = if (selected) AccentOrange.copy(alpha = 0.08f) else Color.White,
                    shape = RoundedCornerShape(12.dp),
                    border = BorderStroke(if (selected) 1.5.dp else 1.dp, if (selected) AccentOrange else Color(0xFFE5E7EB)),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier.padding(14.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        Text(option.emoji, fontSize = 24.sp)
                        Column(modifier = Modifier.weight(1f)) {
                            Text(option.displayName, fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
                            Text(option.description, color = Color.Gray, fontSize = 13.sp)
                        }
                        if (selected) {
                            Icon(Icons.Default.CheckCircle, contentDescription = null, tint = AccentOrange)
                        }
                    }
                }
            }
        }

        // Departure windows
        SectionLabel(icon = "🕐", title = "Preferred departure times")
        LazyVerticalGrid(
            columns = GridCells.Fixed(2),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.height(150.dp)
        ) {
            items(DepartureWindow.values()) { window ->
                val selected = profile.preferredDepartureWindows.contains(window)
                Surface(
                    onClick = {
                        val updated = if (selected)
                            profile.preferredDepartureWindows - window
                        else
                            profile.preferredDepartureWindows + window
                        onUpdate(profile.copy(preferredDepartureWindows = updated))
                    },
                    color = if (selected) AccentOrange else Color.White,
                    shape = RoundedCornerShape(12.dp),
                    border = BorderStroke(1.dp, if (selected) AccentOrange else Color(0xFFE5E7EB)),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(
                        modifier = Modifier.padding(10.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Text(window.displayName, fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                            color = if (selected) Color.White else Color.Black)
                        Text(window.timeRange, fontSize = 11.sp,
                            color = if (selected) Color.White.copy(alpha = 0.8f) else Color.Gray)
                    }
                }
            }
        }

        // Max layover
        SectionLabel(icon = "⏱️", title = "Maximum layover")
        Surface(
            color = Color.White, shape = RoundedCornerShape(12.dp),
            border = BorderStroke(1.dp, Color(0xFFE5E7EB)),
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text(
                    text = if (profile.maxLayoverHours == 0) "Direct flights only" else "${profile.maxLayoverHours}h max",
                    fontWeight = FontWeight.Bold, fontSize = 16.sp, color = PrimaryBlue
                )
                Slider(
                    value = profile.maxLayoverHours.toFloat(),
                    onValueChange = { onUpdate(profile.copy(maxLayoverHours = it.toInt())) },
                    valueRange = 0f..12f, steps = 11,
                    colors = SliderDefaults.colors(thumbColor = AccentOrange, activeTrackColor = AccentOrange)
                )
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text("Direct only", fontSize = 12.sp, color = Color.Gray)
                    Text("12 hours", fontSize = 12.sp, color = Color.Gray)
                }
            }
        }

        // Direct flights toggle
        Surface(
            color = Color.White, shape = RoundedCornerShape(12.dp),
            border = BorderStroke(1.dp, Color(0xFFE5E7EB)),
            modifier = Modifier.fillMaxWidth()
        ) {
            Row(modifier = Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                Column(modifier = Modifier.weight(1f)) {
                    Text("Prefer direct flights", fontWeight = FontWeight.Medium, fontSize = 15.sp)
                    Text("Show direct options first", color = Color.Gray, fontSize = 13.sp)
                }
                Switch(
                    checked = profile.directFlightsPreferred,
                    onCheckedChange = { onUpdate(profile.copy(directFlightsPreferred = it)) },
                    colors = SwitchDefaults.colors(checkedThumbColor = AccentOrange, checkedTrackColor = AccentOrange.copy(alpha = 0.4f))
                )
            }
        }

        Spacer(modifier = Modifier.height(8.dp))
    }
}

// ── Step 3: Memberships ───────────────────────────────────────────────────────

@Composable
private fun Step3Memberships(profile: UserProfile, onUpdate: (UserProfile) -> Unit) {
    val popularPrograms = listOf(
        "ANA" to "ANA Mileage Club",
        "UA"  to "United MileagePlus",
        "DL"  to "Delta SkyMiles",
        "AA"  to "American AAdvantage",
        "JL"  to "JAL Mileage Bank",
        "SQ"  to "Singapore KrisFlyer",
        "CX"  to "Cathay Asia Miles",
        "EK"  to "Emirates Skywards",
        "LH"  to "Lufthansa Miles & More",
        "BA"  to "British Airways Avios",
        "KE"  to "Korean Air SKYPASS",
        "QR"  to "Qatar Privilege Club"
    )

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(24.dp)
    ) {
        StepHeader(
            title = "Your memberships",
            subtitle = "We'll prioritize flights that earn miles on your existing programs."
        )

        // Added programs
        if (profile.loyaltyPrograms.isNotEmpty()) {
            SectionLabel(icon = "⭐", title = "Your programs")
            Surface(
                color = Color.White, shape = RoundedCornerShape(12.dp),
                border = BorderStroke(1.dp, Color(0xFFE5E7EB)), modifier = Modifier.fillMaxWidth()
            ) {
                Column {
                    profile.loyaltyPrograms.forEachIndexed { i, program ->
                        if (i > 0) HorizontalDivider(modifier = Modifier.padding(start = 16.dp))
                        Row(
                            modifier = Modifier.padding(12.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            Surface(color = PrimaryBlue, shape = RoundedCornerShape(8.dp)) {
                                Text(
                                    program.airlineCode,
                                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                                    color = Color.White, fontWeight = FontWeight.Black, fontSize = 13.sp
                                )
                            }
                            Column(modifier = Modifier.weight(1f)) {
                                Text(program.programName, fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
                                Text(program.tier.displayName, color = Color.Gray, fontSize = 12.sp)
                            }
                            IconButton(onClick = {
                                onUpdate(profile.copy(loyaltyPrograms = profile.loyaltyPrograms.filter { it.id != program.id }))
                            }) {
                                Icon(Icons.Default.Close, contentDescription = "Remove", tint = Color.Gray)
                            }
                        }
                    }
                }
            }
        }

        // Quick add grid
        SectionLabel(icon = "➕", title = "Add a loyalty program")
        LazyVerticalGrid(
            columns = GridCells.Fixed(2),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.height(360.dp)
        ) {
            items(popularPrograms) { (code, name) ->
                val alreadyAdded = profile.loyaltyPrograms.any { it.airlineCode == code }
                Surface(
                    onClick = {
                        if (!alreadyAdded) {
                            val newProgram = LoyaltyProgram(programName = name, airlineCode = code)
                            onUpdate(profile.copy(loyaltyPrograms = profile.loyaltyPrograms + newProgram))
                        }
                    },
                    color = if (alreadyAdded) Color(0xFFF0FDF4) else Color.White,
                    shape = RoundedCornerShape(10.dp),
                    border = BorderStroke(1.dp, if (alreadyAdded) Color(0xFF22C55E) else Color(0xFFE5E7EB)),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier.padding(10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Surface(
                            color = if (alreadyAdded) Color(0xFF22C55E) else PrimaryBlue,
                            shape = RoundedCornerShape(6.dp)
                        ) {
                            Text(
                                code, modifier = Modifier.padding(horizontal = 6.dp, vertical = 4.dp),
                                color = Color.White, fontWeight = FontWeight.Black, fontSize = 11.sp
                            )
                        }
                        Text(name, fontSize = 11.sp, fontWeight = FontWeight.Medium,
                            modifier = Modifier.weight(1f), maxLines = 2)
                    }
                }
            }
        }

        // Alliance preference
        SectionLabel(icon = "🌐", title = "Preferred alliance")
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            AlliancePreference.values().forEach { alliance ->
                val selected = profile.alliancePreference == alliance
                FilterChip(
                    selected = selected,
                    onClick = { onUpdate(profile.copy(alliancePreference = alliance)) },
                    label = { Text(alliance.displayName, fontSize = 12.sp) },
                    colors = FilterChipDefaults.filterChipColors(
                        selectedContainerColor = PrimaryBlue,
                        selectedLabelColor = Color.White
                    )
                )
            }
        }

        Spacer(modifier = Modifier.height(8.dp))
    }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

@Composable
private fun StepHeader(title: String, subtitle: String) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(title, fontSize = 28.sp, fontWeight = FontWeight.Black, color = Color.Black)
        Text(subtitle, fontSize = 15.sp, color = Color.Gray, lineHeight = 22.sp)
    }
}

@Composable
private fun SectionLabel(icon: String, title: String) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(icon, fontSize = 16.sp)
        Text(title, fontSize = 16.sp, fontWeight = FontWeight.Bold, color = Color.Black)
    }
}
