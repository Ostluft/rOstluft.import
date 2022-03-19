#' Importiert Daten
#'
#' Diese Funktionen importiert Daten gemäss einer Konfiguration in einen lokalen
#' rolf rds store. Damit der Import durchgeführt werden kann, müssen folgende
#' Anforderungen erfüllt sein:
#'
#' * Eine Lesefunktion für die Daten muss entweder als Funktion in einem Package
#'   oder im globalen Enviroment existieren
#' * Der Store enthält die notwendigen Metadaten
#'
#' Aktuell werden als Quelle curl Downloads (ftp, http) und das Dateisystem unterstütz.
#'
#' @section config:
#' Die Konfiguration wird am einfachsten in einer externen yaml Datei gespeichert.
#' Eine Beschreibung der verschiedenen Optionen ist in der Beispieldatei
#' `config_mythenquai.yml` enthalten.
#'
#' @section logging:
#' Das Packaging nutzt einen [lgr::lgr] Package Level Logger mit dem Namen
#' "rOstluft.import". Mehr Infos in der [lgr Vignette](https://s-fleck.github.io/lgr/articles/lgr.html)
#'
#'
#' @param config Liste mit sämtlichen Konfigurationsoptionen
#'
#' @return invisible(NULL)
#' @export
#'
#' @examples
#' lg <- lgr::get_logger("rOstluft.import")
#' lg$set_threshold("trace")
#'
#' config_file <- system.file("extdata", "config_mythenquai.yml", package = "rOstluft.import")
#' config <- yaml::read_yaml(config_file)
#' import(config)
import <- function(config) {
  lg$info("Starte import")
  dates <- create_date_sequence(config)
  df <- create_plan_df(dates, config)

  if (config$source_typ == "curl") {
    download_files(df, config)
  } else if (config$source_typ == "copy") {
    copy_files(df, config)
  } else {
    msg <- sprintf("Unbekannte Quelle in config$source <%s>!", config$source_typ)
    lg$error(msg)
    rlang::abort(msg, "invalid_config$source")
  }

  import_files(df, config)
  lg$info("Import beendet")
}
