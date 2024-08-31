# Benötigte Bibliothek laden
library(ggplot2)
library(dplyr)  

# Datei einlesen und die ersten 6 Zeilen überspringen
data <- read.csv("E:/Desktop/FoPra_Sim experimentALL-table.csv", 
                 skip = 6, 
                 header = TRUE, 
                 sep = ",")

dateiname <- basename("E:/Desktop/FoPra_Sim experimentALL-table.csv")

# Alle " Zeichen entfernen
data_clean <- data.frame(lapply(data, function(x) gsub("\"", "", x)))

# Spaltennamen manuell setzen
colnames(data_clean) <- c("run_number", "sharing_prob", "commenting_prob", 
                          "unfollow_prob", "follow_prob", "rewiring_probability", 
                          "posts_frequency", "seed", "liking_prob", "num_nodes", 
                          "use_random_seed","seeing_prob","step", "adopter", "non-adopter", 
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
ggplot(data_filtered, aes(x = step, y = adopter)) +
  geom_line(size = 2.5) +
  labs(title = "ID des Modells ohne Änderung",
       x = "Step",
       y = "Adaptierer") +
  theme_minimal(base_size = 54)

# Ausgabe der Werte - Step 400
cat("Dateiname:", dateiname, "\n")
value_at_step_400


