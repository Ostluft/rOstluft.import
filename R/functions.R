#' wrapper um glue:glue and format
#'
#' Dadurch das es ein Wrapper um [glue::glue()] und [base::format()] ist, kann
#' man zum einem das Datum einfach mit den üblichen Formatierungskürzel wie `"%Y"`
#' formatieren oder Ausdrücke einfügen.
#'
#' @param date von der generierten Sequenz (POSIXct oder Date)
#' @param tpl Template String aus der config
#' @param ... Möglichkeit weitere Parameter für [glue::glue()] einzufügen
#'
#' @return formatierter String
#' @export
#'
#' @examples
#' to <- lubridate::floor_date(lubridate::now("GMT"), "day")
#' from <- to - lubridate::period("6 days")
#' dates <- seq(from, to, by = "1 day")
#'
#' tpl <- "[..]/mythenquai?startDate={format(date - 1, '%Y-%m-%d')}&endDate=%Y-%m-%d"
#'
#' apply_tpl_to_date(dates, tpl)
#'
apply_tpl_to_date <- function(date, tpl, ...) {
  format(date, glue::glue(tpl))
}



#' Zeitpunkte für die Dateinamen generieren
#'
#' Generiert eine Sequence von Zeitpunkt aus der config
#'
#' @param config Konfiguration für gesamten import
#'
#' @return Vector von Date oder POSIXct
#' @export
#'
#' @examples
#' config_file <- system.file("extdata", "config_mythenquai.yml", package = "rOstluft.import")
#' config <- yaml::read_yaml(config_file)
#'
#' create_date_sequence(config)
create_date_sequence <- function(config) {
  now <- lubridate::now(config$tz)
  to <- lubridate::floor_date(now, config$floor_now)
  to <- lubridate::add_with_rollback(to, -lubridate::period(config$to_offset))
  from <- lubridate::add_with_rollback(to, -lubridate::period(config$period))
  seq(from, to, by = config$interval)
}


#' Erzeuge Dataframe aller Dateien
#'
#' Erzeugt einen Dataframe mit einer Zeile für jedes Datum/Zeitpunkt. Folgende Angaben
#' ist in jeder Zeile:
#'
#' * input_fn: Input Dateiname/URL zum kopieren/herunterladen
#' * cache_fn: Cache Dateiname der Rohdaten
#' * imported_fn: Import Dateiname für die normalisierten und importierten Daten
#' * cache_fn_exists: exisitiert die Cache Datei bereits?
#' * imported_fn_exists: exisitiert die Import Datei bereits?
#'
#'
#' @param dates Sequence von Date/POSIXct
#' @param config Konfiguration für gesamten import
#'
#' @return tibble mit allen notwendigen Angaben für den Import
#' @export
#'
#' @examples
#' config_file <- system.file("extdata", "config_mythenquai.yml", package = "rOstluft.import")
#' config <- yaml::read_yaml(config_file)
#'
#' dates <- create_date_sequence(config)
#' plan <- create_plan_df(dates, config)
#'
#' tibble::glimpse(plan)
create_plan_df <- function(dates, config) {
  df <- tibble::tibble(date = dates)

  df <- dplyr::mutate(df,
    input_fn = apply_tpl_to_date(.data$date, config$input_fn_tpl),
    cache_fn = apply_tpl_to_date(.data$date, config$cache_fn_tpl),
    imported_fn = apply_tpl_to_date(.data$date, config$imported_fn_tpl),
    cache_fn_exists = fs::file_exists(.data$cache_fn),
    imported_fn_exists = fs::file_exists(.data$imported_fn)
  )

  df
}


#' Kopieren der Inputdateien mit [fs::copy()]
#'
#' Filtert den Dataframe basieren auf den bereits vorhanden Dateien im Cache und importierten
#'
#' @param df Dataframe mit Liste der Dateien
#' @param config Konfiguration für gesamten import
#' @param ... aktuell nicht gebraucht, eventuell in Zukunft zur Überschreibung von config Werten
#'
#' @return invisible(NULL)
#' @export
copy_files <- function(df, config, ...) {
  from <- dplyr::first(df$date)
  to <- dplyr::last(df$date)

  df <- dplyr::filter(df, .data$imported_fn_exists == FALSE, .data$cache_fn_exists == FALSE)

  if (nrow(df) > 0) {
    lg$info("Kopiere fehlende Dateien für den Zeitraum von %s bis %s: %s",
             from, to, stringr::str_c(df$input_fn, collapse = ", "))
    purrr::map2(df$input_fn, df$cache_fn, fs_file_copy_warp, config = config)
  } else {
    lg$info("Kein kopieren notwendig. Alle Dateien bereits gecached oder importiert.")
  }
  invisible(NULL)
}


#' Herunterladen der Inputdateien mit [curl::curl_download()]
#'
#' Filtert den Dataframe basieren auf den bereits vorhanden Dateien im Cache und importierten
#'
#' @param df Dataframe mit Liste der Dateien
#' @param config Konfiguration für gesamten import
#' @param ... aktuell nicht gebraucht, eventuell in Zukunft zur Überschreibung von config Werten
#'
#' @return invisible(NULL)
#' @export
download_files <- function(df, config, ...) {
  from <- dplyr::first(df$date)
  to <- dplyr::last(df$date)

  # herausfinden welche files heruntergeladen werden müssen: noch nicht importiert und nicht gecached
  df <- dplyr::filter(df, .data$imported_fn_exists == FALSE, .data$cache_fn_exists == FALSE)

  if (nrow(df) > 0) {
    lg$info("Download fehlende Dateien für den Zeitraum von %s bis %s: %s",
            from, to, stringr::str_c(df$input_fn, collapse = ", "))

    handle <- curl::new_handle()
    if (rlang::has_name(config, "curl_opts") && length(config$curl_opts) > 0) {
      handle <- curl::handle_setopt(handle, .list = config$curl_opts)
    }

    if (rlang::has_name(config, "curl_header") && length(config$curl_header) > 0) {
      handle <- curl::handle_setheaders(handle, .list = config$curl_header)
    }


    purrr::map2(df$input_fn, df$cache_fn, curl_download_wrap, handle = handle, config = config)
  } else {
    lg$info("Kein Download notwendig. Alle Dateien bereits gecached oder importiert.")
  }
  invisible(NULL)
}


#' Import Dateien im Plan Dataframe
#'
#' Filtert den Dataframe basieren auf den bereits vorhanden Dateien im Cache und importierten
#'
#' @param df Dataframe mit Liste der Dateien
#' @param config Konfiguration für gesamten import
#' @param ... aktuell nicht gebraucht, eventuell in Zukunft zur Überschreibung von config Werten
#'
#' @return invisible(NULL)
#' @export
import_files <- function(df, config, ...) {
  df <- dplyr::filter(df, .data$imported_fn_exists == FALSE)

  if (nrow(df) == 0) {
    lg$info("Alle Dateien bereits importiert.")
  } else {
    purrr::map2(df$cache_fn, df$imported_fn, read_normalize_put_file, config = config)
  }
  invisible(NULL)
}

#' @keywords internal
read_normalize_put_file <- function(cache_fn, imported_fn, config, ...) {
  lg$info("Lese Datei: %s", cache_fn)
  f <- rlang::call2(config$reading_function, cache_fn, .ns = config$reading_function_ns)

  tryCatch(
    expr = {
      data <- base::eval(f)

      s <- get_store(config)
      meta <- s$get_meta(config$meta_key)[[1]]

      if (rlang::has_name(config, "meta")) {
        lg$debug("Wende Metainformationen an")

        reduce_meta <- function(data, .x) {
          lg$trace("data$%s = meta[meta$%s == data$%s]$%s",
                         .x$data_dest, .x$meta_key, .x$data_src, .x$meta_val)
          rOstluft::meta_apply(data, meta, .x$data_src, .x$data_dest, .x$meta_key, .x$meta_val)
        }

        data <- purrr::reduce(config$meta, reduce_meta, .init = data)
      }

      s$put(data)
      lg$info("Schreibe importierte Daten in Datei: %s", imported_fn)
      fs::dir_create(fs::path_dir(imported_fn))
      saveRDS(data, imported_fn)

      if (config$delete_cache == TRUE) {
        lg$info("Lösche Cache Datei: %s", cache_fn)
        fs::file_delete(cache_fn)
      }
    },
    error = function(err) {
      msg <- sprintf("Datei %s konnte nicht importiert werden. Error: %s", cache_fn, err)
      if (config$missing_files == "warn") {
        lg$warn(msg)
        rlang::warn(msg, "failed_import", parent = err)
      } else {
        lg$error(msg)
        rlang::abort(msg, "failed_import", parent = err)
      }
    }
  )


}

#' @keywords internal
fs_file_copy_warp <- function(path, new_path, overwrite = FALSE, config) {
  fs::dir_create(fs::path_dir(new_path))
  tryCatch(
    fs::file_copy(path, new_path, overwrite),
    error = function(err) {
      msg <- sprintf("Datei %s konnte nicht kopiert werden. Error: %s", path, err)
      if (config$missing_files == "warn") {
        lg$warn(msg)
        rlang::warn(msg, "failed_copy", parent = err)
      } else {
        lg$error(msg)
        rlang::abort(msg, "failed_copy", parent = err)
      }
    }
  )
}

#' @keywords internal
curl_download_wrap <- function(url, destfile, quiet = TRUE, mode = "wb", handle = curl::new_handle(), config) {
  fs::dir_create(fs::path_dir(destfile))
  tryCatch(
    curl::curl_download(url, destfile, quiet, mode, handle),
    error = function(err) {
      msg <- sprintf("Datei %s konnte nicht heruntergeladen werden. Error: %s", url, err)
      if (config$missing_files == "warn") {
        lg$warn(msg)
        rlang::warn(msg, "failed_download", parent = err)
      } else {
        lg$error(msg)
        rlang::abort(msg, "failed_download", parent = err)
      }
    }
  )
}


#' Erzeugt lokalen rolf rds store
#'
#' @param config Konfiguration für gesamten import
#'
#' @return schreibbarer lokaler rOstluft
#' @export
#'
#' @examples
#' config_file <- system.file("extdata", "config_mythenquai.yml", package = "rOstluft.import")
#' config <- yaml::read_yaml(config_file)
#'
#' get_store(config)
get_store <- function(config) {
  rOstluft::storage_local_rds(config$store_name, rOstluft::format_rolf(), read.only = FALSE)
}
