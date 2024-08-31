# Benötigte Bibliothek laden
library(ggplot2)
library(dplyr)  

# Datei einlesen und die ersten 6 Zeilen überspringen
data <- read.csv("E:/Desktop/FoPra_Sim experiment3_like-table.csv", 
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
data_selected <- data_clean[, c("run_number", "liking_prob", "step", "adopter", "non-adopter", "moderate-interestet")]

# Spalten in num-Werte
data_selected[] <- lapply(data_selected, function(x) as.numeric(as.character(x)))

# Daten gruppieren und summieren
data_summarized <- aggregate(cbind(adopter, `non-adopter`, `moderate-interestet`) ~ liking_prob + step, 
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
ggplot(data_filtered, aes(x = step, y = adopter, color = factor(liking_prob), linetype = factor(liking_prob))) +
  geom_line() +
  labs(title = "ID mit unterschiedlicher Like Wahr.",
       x = "Step",
       y = "Adaptierer",
       color = "Wahr. Like",
       linetype = "Wahr. Like") +
  theme_minimal()

# Ausgabe der Werte - Step 400
cat("Dateiname:", dateiname, "\n")
value_at_step_400

