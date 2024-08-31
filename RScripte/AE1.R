# Benötigte Bibliothek laden
library(ggplot2)
library(dplyr)  

# Datei einlesen und die ersten 6 Zeilen überspringen
data <- read.csv("E:/Desktop/FoPra_Sim experiment1-table.csv", 
                 skip = 6, 
                 header = TRUE, 
                 sep = ",")

dateiname <- basename("E:/Desktop/FoPra_Sim experiment1-table.csv")

# Alle " Zeichen entfernen
data_clean <- data.frame(lapply(data, function(x) gsub("\"", "", x)))

# Spaltennamen manuell setzen
colnames(data_clean) <- c("run_number", "sharing_prob", "commenting_prob", 
                          "unfollow_prob", "follow_prob", "rewiring_probability", 
                          "posts_frequency", "seed", "liking_prob", "num_nodes", 
                          "use_random_seed", "step", "adopter", "non-adopter", 
                          "moderate-interestet")


# Spalten wählen
data_selected <- data_clean[, c("run_number", "num_nodes", "step", "adopter", "non-adopter", "moderate-interestet")]

# Spalten in num-Werte
data_selected[] <- lapply(data_selected, function(x) as.numeric(as.character(x)))

# Daten gruppieren und summieren
data_summarized <- aggregate(cbind(adopter, `non-adopter`, `moderate-interestet`) ~ num_nodes + step, 
                             data = data_selected, 
                             FUN = mean)

# Überprüfen, ob die Spalten korrekt ausgewählt wurden
colnames(data_selected)
head(data_selected)

# Nur jeden 25. Step berücksichtigen
data_filtered <- data_summarized[data_summarized$step %% 25 == 0, ]

# Wert bei Step 400 berechnen
value_at_step_400 <- data_filtered %>%
  filter(step == 400)

# Diagramm erstellen
ggplot(data_filtered, aes(x = step, y = adopter, color = factor(num_nodes), linetype = factor(num_nodes))) +
  geom_line(size = 2.5) +
  labs(title = "ID mit unterschiedlicher Anzahl an Agenten",
       x = "Step",
       y = "Adaptierer",
       color = "Anz. Agenten",
       linetype = "Anz. Agenten") +
  theme_minimal(base_size = 54)

# Überschreitung der Schwellenwerte 0,25; 0,5; 0,75
thresholds <- c(0.6, 0.65, 0.7, 0.75, 0.8, 0.85, 0.9, 0.95)

get_threshold_steps <- function(data, threshold) {
  data %>%
    group_by(num_nodes) %>%
    filter(adopter >= threshold) %>%
    slice_min(step) %>%
    select(num_nodes, step, adopter)
}

threshold_results <- lapply(thresholds, function(t) {
  result <- get_threshold_steps(data_summarized, t)
  result$threshold <- t
  return(result)
})

threshold_results <- do.call(rbind, threshold_results)

# Ausgabe der Werte - Step 400
cat("Dateiname:", dateiname, "\n")
value_at_step_400
print(threshold_results, n = 1000)


