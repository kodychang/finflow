package com.shokoforms.android

import android.content.Context
import android.view.View
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.ViewCompositionStrategy
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.Alignment
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

object ComposeBridge {
    @JvmStatic
    fun appBar(
        context: Context,
        title: String,
        subtitle: String,
        supportLabel: String,
        darkMode: Boolean,
        accentColor: Int,
        onSupport: Runnable
    ): View {
        return ComposeView(context).apply {
            setViewCompositionStrategy(ViewCompositionStrategy.DisposeOnDetachedFromWindow)
            setContent {
                ShokoTheme(darkMode = darkMode, accentColor = accentColor) {
                    AppBar(
                        title = title,
                        subtitle = subtitle,
                        supportLabel = supportLabel,
                        onSupport = onSupport
                    )
                }
            }
        }
    }

    @JvmStatic
    fun homeHero(
        context: Context,
        title: String,
        subtitle: String,
        documentsLabel: String,
        documentsCount: Int,
        projectsLabel: String,
        projectsCount: Int,
        customersLabel: String,
        customersCount: Int,
        darkMode: Boolean,
        accentColor: Int
    ): View {
        return ComposeView(context).apply {
            setViewCompositionStrategy(ViewCompositionStrategy.DisposeOnDetachedFromWindow)
            setContent {
                ShokoTheme(darkMode = darkMode, accentColor = accentColor) {
                    Surface(color = MaterialTheme.colorScheme.background) {
                        HomeHeroCard(
                            title = title,
                            subtitle = subtitle,
                            metrics = listOf(
                                Metric(documentsLabel, documentsCount.toString()),
                                Metric(projectsLabel, projectsCount.toString()),
                                Metric(customersLabel, customersCount.toString())
                            )
                        )
                    }
                }
            }
        }
    }

    @JvmStatic
    fun bottomNav(
        context: Context,
        selected: String,
        homeLabel: String,
        createLabel: String,
        previewLabel: String,
        dataLabel: String,
        settingsLabel: String,
        darkMode: Boolean,
        accentColor: Int,
        onHome: Runnable,
        onCreate: Runnable,
        onPreview: Runnable,
        onData: Runnable,
        onSettings: Runnable
    ): View {
        return ComposeView(context).apply {
            setViewCompositionStrategy(ViewCompositionStrategy.DisposeOnDetachedFromWindow)
            setContent {
                ShokoTheme(darkMode = darkMode, accentColor = accentColor) {
                    FloatingBottomNav(
                        items = listOf(
                            NavItem("home", homeLabel, "01", onHome),
                            NavItem("create", createLabel, "02", onCreate),
                            NavItem("preview", previewLabel, "03", onPreview),
                            NavItem("data", dataLabel, "04", onData),
                            NavItem("settings", settingsLabel, "05", onSettings)
                        ),
                        selected = selected
                    )
                }
            }
        }
    }
}

private data class Metric(val label: String, val value: String)
private data class NavItem(val key: String, val label: String, val index: String, val action: Runnable)

@Composable
private fun ShokoTheme(
    darkMode: Boolean,
    accentColor: Int,
    content: @Composable () -> Unit
) {
    val seed = Color(accentColor)
    val useDark = darkMode
    val colors = if (useDark) {
        darkColorScheme(
            primary = seed,
            secondary = Color(0xFF8DA399),
            surface = Color(0xFF22272C),
            surfaceVariant = Color(0xFF303840),
            background = Color(0xFF15191D),
            onSurface = Color(0xFFE8ECE9),
            onSurfaceVariant = Color(0xFFB8C2BC)
        )
    } else {
        lightColorScheme(
            primary = seed,
            secondary = Color(0xFF8DA399),
            surface = Color(0xFFFBFAF7),
            surfaceVariant = Color(0xFFE9EEEA),
            background = Color(0xFFF4F6F4),
            onSurface = Color(0xFF1E2A32),
            onSurfaceVariant = Color(0xFF68737D)
        )
    }
    MaterialTheme(colorScheme = colors, content = content)
}

@Composable
private fun AppBar(
    title: String,
    subtitle: String,
    supportLabel: String,
    onSupport: Runnable
) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        color = MaterialTheme.colorScheme.surface
    ) {
        Row(
            modifier = Modifier.padding(start = 18.dp, top = 10.dp, end = 14.dp, bottom = 12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    color = MaterialTheme.colorScheme.onSurface,
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = subtitle,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    fontSize = 12.sp,
                    lineHeight = 16.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
            Surface(
                shape = RoundedCornerShape(18.dp),
                color = MaterialTheme.colorScheme.surfaceVariant,
                onClick = { onSupport.run() }
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = supportLabel,
                        color = MaterialTheme.colorScheme.onSurface,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.SemiBold,
                        maxLines = 1
                    )
                }
            }
        }
    }
}

@Composable
private fun FloatingBottomNav(items: List<NavItem>, selected: String) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 14.dp, end = 14.dp, top = 8.dp, bottom = 18.dp),
        shape = RoundedCornerShape(30.dp),
        color = MaterialTheme.colorScheme.surface.copy(alpha = 0.96f),
        tonalElevation = 2.dp,
        shadowElevation = 8.dp
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 7.dp, vertical = 6.dp),
            horizontalArrangement = Arrangement.spacedBy(5.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            items.forEach { item ->
                NordicNavItem(
                    item = item,
                    selected = item.key == selected,
                    modifier = Modifier.weight(1f)
                )
            }
        }
    }
}

@Composable
private fun NordicNavItem(item: NavItem, selected: Boolean, modifier: Modifier = Modifier) {
    val container = if (selected) MaterialTheme.colorScheme.primary else Color.Transparent
    val content = if (selected) Color.White else MaterialTheme.colorScheme.onSurfaceVariant
    Surface(
        modifier = modifier,
        shape = RoundedCornerShape(22.dp),
        color = container,
        onClick = { item.action.run() }
    ) {
        Column(
            modifier = Modifier.padding(vertical = 7.dp, horizontal = 4.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Surface(
                shape = RoundedCornerShape(8.dp),
                color = if (selected) Color.White.copy(alpha = 0.16f) else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.72f)
            ) {
                Text(
                    text = item.index,
                    color = content,
                    fontSize = 9.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(horizontal = 7.dp, vertical = 2.dp)
                )
            }
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = item.label,
                color = content,
                fontSize = 10.sp,
                fontWeight = if (selected) FontWeight.Bold else FontWeight.SemiBold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            if (selected) {
                Spacer(modifier = Modifier.height(4.dp))
                Surface(
                    modifier = Modifier.width(18.dp).height(3.dp),
                    shape = RoundedCornerShape(3.dp),
                    color = Color.White.copy(alpha = 0.82f)
                ) {}
            }
        }
    }
}

@Composable
private fun HomeHeroCard(
    title: String,
    subtitle: String,
    metrics: List<Metric>
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 10.dp),
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp)
    ) {
        Column(modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp)) {
            Text(
                text = title,
                color = MaterialTheme.colorScheme.onSurface,
                fontSize = 24.sp,
                fontWeight = FontWeight.Bold
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = subtitle,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                fontSize = 13.sp,
                lineHeight = 18.sp
            )
            Spacer(modifier = Modifier.height(14.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                metrics.forEach { metric ->
                    MetricTile(metric = metric, modifier = Modifier.weight(1f))
                }
            }
        }
    }
}

@Composable
private fun MetricTile(metric: Metric, modifier: Modifier = Modifier) {
    Surface(
        modifier = modifier,
        shape = RoundedCornerShape(10.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.68f)
    ) {
        Column(modifier = Modifier.padding(horizontal = 10.dp, vertical = 9.dp)) {
            Text(
                text = metric.value,
                color = MaterialTheme.colorScheme.onSurface,
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold
            )
            Spacer(modifier = Modifier.height(2.dp))
            Text(
                text = metric.label,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                fontSize = 11.sp,
                fontWeight = FontWeight.SemiBold
            )
        }
    }
}
