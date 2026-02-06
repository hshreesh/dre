#!/usr/bin/env Rscript

# Script to calculate annual average daily precipitation from 33 years of data (1991-2023)

# Load required library
suppressPackageStartupMessages(library(lubridate))

# Read the precipitation data
data <- read.csv("NFWF_ppt.txt", header = TRUE)

# Convert date column to Date format
data$date <- as.Date(as.character(data$date), format = "%Y%m%d")

# Extract month and day (ignoring year)
data$month <- month(data$date)
data$day <- day(data$date)

# Create a day-of-year variable (1-366 for leap years, 1-365 for regular years)
data$doy <- yday(data$date)

# Handle leap years: combine Feb 29 (day 60) with Feb 28 (day 59)
# For leap years, days after Feb 29 are shifted by 1
data$doy_adjusted <- ifelse(
  leap_year(data$date) & data$doy > 60,
  data$doy - 1,  # Shift back by 1 for days after Feb 29 in leap years
  ifelse(
    data$month == 2 & data$day == 29,
    59,  # Assign Feb 29 to the same day as Feb 28
    data$doy
  )
)

# Calculate annual average for each day of year (1-365)
annual_avg <- aggregate(value ~ doy_adjusted, data = data, FUN = mean)

# Sort by day of year
annual_avg <- annual_avg[order(annual_avg$doy_adjusted), ]

# Create proper date labels for a non-leap year (e.g., 2023)
reference_year <- 2023  # Use a non-leap year for reference dates
reference_dates <- as.Date(paste0(reference_year, "-01-01")) + (annual_avg$doy_adjusted - 1)

# Add month-day labels
annual_avg$month <- month(reference_dates)
annual_avg$day <- day(reference_dates)
annual_avg$date_label <- format(reference_dates, "%m-%d")

# Rename columns for clarity
colnames(annual_avg)[colnames(annual_avg) == "doy_adjusted"] <- "day_of_year"
colnames(annual_avg)[colnames(annual_avg) == "value"] <- "avg_precipitation"

# Reorder columns
annual_avg <- annual_avg[, c("day_of_year", "month", "day", "date_label", "avg_precipitation")]

cat("Total days:", nrow(annual_avg), "\n")
cat("Mean annual precipitation:", round(sum(annual_avg$avg_precipitation), 2), "mm\n")
cat("Average daily precipitation:", round(mean(annual_avg$avg_precipitation), 4), "mm\n\n")

# Save to CSV file
output_file <- "annual_average_precipitation.csv"
write.csv(annual_avg, output_file, row.names = FALSE)

# 1. Calculate total daily rainfall (sum for each day across all years)
total_daily <- aggregate(value ~ doy_adjusted, data = data, FUN = sum)
colnames(total_daily) <- c("day_of_year", "total_precipitation")
total_daily <- total_daily[order(total_daily$day_of_year), ]

# Add date labels
reference_dates_total <- as.Date(paste0(reference_year, "-01-01")) + (total_daily$day_of_year - 1)
total_daily$month <- month(reference_dates_total)
total_daily$day <- day(reference_dates_total)
total_daily$date_label <- format(reference_dates_total, "%m-%d")

# Reorder columns
total_daily <- total_daily[, c("day_of_year", "month", "day", "date_label", "total_precipitation")]

# Save total daily rainfall
write.csv(total_daily, "total_daily_precipitation.csv", row.names = FALSE)

# Overall statistics
cat("Overall Statistics:\n")
cat("  Mean precipitation:", round(mean(data$value, na.rm = TRUE), 4), "mm/day\n")
cat("  Median precipitation:", round(median(data$value, na.rm = TRUE), 4), "mm/day\n")
cat("  Average annual precipitation:", round(sum(data$value, na.rm = TRUE) / 33, 2), "mm/year\n\n")

# Percentiles
cat("Percentiles:\n")
percentiles <- quantile(data$value, probs = c(0.25, 0.50, 0.75, 0.90, 0.95, 0.99), na.rm = TRUE)
for (i in 1:length(percentiles)) {
  cat(sprintf("  %s: %.4f mm\n", names(percentiles)[i], percentiles[i]))
}
cat("\n")

# Extract only wet days (precipitation > 0) for return period analysis
wet_data <- data$value[data$value > 0]

if (length(wet_data) > 0) {
  # Sort precipitation values in descending order
  sorted_precip <- sort(wet_data, decreasing = TRUE)
  
  # Calculate return periods using Weibull plotting position
  n <- length(sorted_precip)
  ranks <- 1:n
  return_periods <- (n + 1) / ranks
  
  # Create return period data frame
  return_period_df <- data.frame(
    rank = ranks,
    precipitation = sorted_precip,
    return_period_days = return_periods,
    return_period_years = return_periods / 365.25
  )
  
  # Show key return periods
  cat("Key Return Periods (based on wet days):\n")
  key_periods <- c(30, 90, 180, 365, 730, 1825, 3650, 7300)  # days
  
  for (period in key_periods) {
    if (period <= max(return_period_df$return_period_days)) {
      idx <- which.min(abs(return_period_df$return_period_days - period))
      years <- period / 365.25
      cat(sprintf("  %d-day (%.1f-year) return period: %.2f mm\n", 
                  period, years, return_period_df$precipitation[idx]))
    }
  }
  
  # Save return period analysis
  write.csv(return_period_df[1:min(1000, nrow(return_period_df)), ], 
            "return_period_analysis.csv", row.names = FALSE)
  cat("\nReturn period analysis saved to: return_period_analysis.csv\n")
  cat("(Showing top 1000 events)\n\n")
  
} else {
  cat("No wet days found in the dataset.\n\n")
}

# 4. Annual statistics by year
annual_stats <- data.frame(
  year = integer(),
  total_precip = numeric(),
  mean_precip = numeric(),
  max_precip = numeric(),
  wet_days = integer(),
  stringsAsFactors = FALSE
)

years <- unique(year(data$date))
for (yr in years) {
  yr_data <- data$value[year(data$date) == yr]
  annual_stats <- rbind(annual_stats, data.frame(
    year = yr,
    total_precip = sum(yr_data, na.rm = TRUE),
    mean_precip = mean(yr_data, na.rm = TRUE),
    max_precip = max(yr_data, na.rm = TRUE),
    wet_days = sum(yr_data > 0, na.rm = TRUE)
  ))
}

cat("Annual Statistics Summary:\n")
cat("  Mean annual total:", round(mean(annual_stats$total_precip), 2), "mm\n")
cat("  Std dev of annual total:", round(sd(annual_stats$total_precip), 2), "mm\n")
cat("  Wettest year:", annual_stats$year[which.max(annual_stats$total_precip)], 
    "with", round(max(annual_stats$total_precip), 2), "mm\n")
cat("  Driest year:", annual_stats$year[which.min(annual_stats$total_precip)], 
    "with", round(min(annual_stats$total_precip), 2), "mm\n\n")

# Save annual statistics
write.csv(annual_stats, "annual_statistics.csv", row.names = FALSE)
cat("Annual statistics by year saved to: annual_statistics.csv\n\n")

# Plot 1: Annual average precipitation
png("annual_avg_precipitation_plot.png", width = 1200, height = 600)
par(mar = c(5, 4, 4, 2) + 0.1)
plot(annual_avg$day_of_year, annual_avg$avg_precipitation, 
     type = "l", 
     col = "blue",
     lwd = 2,
     xlab = "Day of Year",
     ylab = "Average Precipitation (mm)",
     main = "Annual Average Daily Precipitation (1991-2023)",
     las = 1)
grid()
dev.off()

# Plot 2: Return period plot
if (exists("return_period_df") && nrow(return_period_df) > 0) {
  png("return_period_plot.png", width = 1200, height = 600)
  par(mar = c(5, 4, 4, 2) + 0.1)
  plot(return_period_df$return_period_years, return_period_df$precipitation,
       log = "x",
       type = "p",
       pch = 20,
       col = "darkred",
       xlab = "Return Period (years)",
       ylab = "Precipitation (mm)",
       main = "Precipitation Return Period Analysis",
       las = 1)
  grid()
  dev.off()
  cat("Return period plot saved to: return_period_plot.png\n")
}

# Plot 4: Annual total precipitation time series
png("annual_total_precipitation_plot.png", width = 1200, height = 600)
par(mar = c(5, 4, 4, 2) + 0.1)
plot(annual_stats$year, annual_stats$total_precip,
     type = "b",
     pch = 19,
     col = "darkgreen",
     xlab = "Year",
     ylab = "Total Annual Precipitation (mm)",
     main = "Annual Total Precipitation (1991-2023)",
     las = 1)
abline(h = mean(annual_stats$total_precip), col = "red", lwd = 2, lty = 2)
legend("topright", legend = "Mean", col = "red", lwd = 2, lty = 2)
grid()
dev.off()
