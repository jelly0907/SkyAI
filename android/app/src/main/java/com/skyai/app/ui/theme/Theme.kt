package com.skyai.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.material3.Typography
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

// SkyAI Colors
private val PrimaryBlue = Color(0xFF1A3C6B)
private val SecondaryOrange = Color(0xFFFF6B35)
private val Surface = Color(0xFFF8F9FA)
private val OnSurface = Color(0xFF1F1F1F)

private val lightColorScheme = lightColorScheme(
    primary = PrimaryBlue,
    onPrimary = Color.White,
    primaryContainer = Color(0xFFD6E4FF),
    onPrimaryContainer = Color(0xFF001449),
    secondary = SecondaryOrange,
    onSecondary = Color.White,
    secondaryContainer = Color(0xFFFFDCC1),
    onSecondaryContainer = Color(0xFF351600),
    tertiary = Color(0xFF0061A4),
    onTertiary = Color.White,
    tertiaryContainer = Color(0xFFD7E7FF),
    onTertiaryContainer = Color(0xFF001C3C),
    error = Color(0xFFB3261E),
    onError = Color.White,
    errorContainer = Color(0xFFF9DEDC),
    onErrorContainer = Color(0xFF410E0B),
    background = Color.White,
    onBackground = OnSurface,
    surface = Surface,
    onSurface = OnSurface,
    surfaceVariant = Color(0xFFE7E0EC),
    onSurfaceVariant = Color(0xFF49454E),
    outline = Color(0xFF79747E),
    outlineVariant = Color(0xFFCAC7D0),
    scrim = Color.Black,
    inverseSurface = Color(0xFF313033),
    inverseOnSurface = Color(0xFFF4EFF4),
    inversePrimary = Color(0xFFB6D4FF)
)

private val darkColorScheme = darkColorScheme(
    primary = Color(0xFFB6D4FF),
    onPrimary = Color(0xFF002A71),
    primaryContainer = Color(0xFF1A3C6B),
    onPrimaryContainer = Color(0xFFD6E4FF),
    secondary = Color(0xFFFFB99D),
    onSecondary = Color(0xFF572700),
    secondaryContainer = Color(0xFF7D4E1E),
    onSecondaryContainer = Color(0xFFFFDCC1),
    tertiary = Color(0xFFA6D3FF),
    onTertiary = Color(0xFF003062),
    tertiaryContainer = Color(0xFF00468A),
    onTertiaryContainer = Color(0xFFD7E7FF),
    error = Color(0xFFF2B8B5),
    onError = Color(0xFF601410),
    errorContainer = Color(0xFF8C1d18),
    onErrorContainer = Color(0xFFF9DEDC),
    background = Color(0xFF1F1F1F),
    onBackground = Color(0xFFE6E1E6),
    surface = Color(0xFF1F1F1F),
    onSurface = Color(0xFFE6E1E6),
    surfaceVariant = Color(0xFF49454E),
    onSurfaceVariant = Color(0xFFCAC7D0),
    outline = Color(0xFF938F99),
    outlineVariant = Color(0xFF49454E),
    scrim = Color.Black,
    inverseSurface = Color(0xFFE6E1E6),
    inverseOnSurface = Color(0xFF313033),
    inversePrimary = Color(0xFF1A3C6B)
)

val SkyAITypography = Typography(
    displayLarge = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.W400,
        fontSize = 57.sp,
        lineHeight = 64.sp,
        letterSpacing = 0.sp
    ),
    displayMedium = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.W400,
        fontSize = 45.sp,
        lineHeight = 52.sp,
        letterSpacing = 0.sp
    ),
    displaySmall = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.W400,
        fontSize = 36.sp,
        lineHeight = 44.sp,
        letterSpacing = 0.sp
    ),
    headlineLarge = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.W400,
        fontSize = 32.sp,
        lineHeight = 40.sp,
        letterSpacing = 0.sp
    ),
    headlineMedium = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.W400,
        fontSize = 28.sp,
        lineHeight = 36.sp,
        letterSpacing = 0.sp
    ),
    headlineSmall = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.W400,
        fontSize = 24.sp,
        lineHeight = 32.sp,
        letterSpacing = 0.sp
    ),
    titleLarge = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.W500,
        fontSize = 22.sp,
        lineHeight = 28.sp,
        letterSpacing = 0.sp
    ),
    titleMedium = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.W500,
        fontSize = 16.sp,
        lineHeight = 24.sp,
        letterSpacing = 0.15.sp
    ),
    titleSmall = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.W500,
        fontSize = 14.sp,
        lineHeight = 20.sp,
        letterSpacing = 0.1.sp
    ),
    bodyLarge = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.W400,
        fontSize = 16.sp,
        lineHeight = 24.sp,
        letterSpacing = 0.15.sp
    ),
    bodyMedium = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.W400,
        fontSize = 14.sp,
        lineHeight = 20.sp,
        letterSpacing = 0.25.sp
    ),
    bodySmall = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.W400,
        fontSize = 12.sp,
        lineHeight = 16.sp,
        letterSpacing = 0.4.sp
    ),
    labelLarge = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.W500,
        fontSize = 14.sp,
        lineHeight = 20.sp,
        letterSpacing = 0.1.sp
    ),
    labelMedium = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.W500,
        fontSize = 12.sp,
        lineHeight = 16.sp,
        letterSpacing = 0.5.sp
    ),
    labelSmall = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.W500,
        fontSize = 11.sp,
        lineHeight = 16.sp,
        letterSpacing = 0.5.sp
    )
)

@Composable
fun SkyAITheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    val colorScheme = if (darkTheme) darkColorScheme else lightColorScheme

    MaterialTheme(
        colorScheme = colorScheme,
        typography = SkyAITypography,
        content = content
    )
}
