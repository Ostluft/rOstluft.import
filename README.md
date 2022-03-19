
<!-- README.md is generated from README.Rmd. Please edit that file -->

# rOstluft.import

<!-- badges: start -->
<!-- badges: end -->

Das Ziel von rOstluft.import ist es einene einfachen und einheitlichen
Prozess für den regelmässigen Import von Daten in einen rOstluft Store
zu definieren.

## Installation

Die aktuelle Version kann von github installiert werden.

``` r
remotes::install_github("Ostluft/rOstluft.import")
```

## Voraussetzungen

Damit der Import erfolgreich ausgeführt werden kann müssen folgende
Voraussetzungen erfüllt sein:

-   Die Daten sind aufgeteilt in Tages-/Monatsdateien (fixes Interval)
-   Lesefunktion mit Rückgabe der Daten im rolf Format
-   Meta Dataframe im lokalen rOstluft rds Store

## Beispiel

``` r
library(rOstluft.import)
# packages uses a lgr Logger
lg <- lgr::get_logger("rOstluft.import")
lg$set_threshold("info")

config_file <- system.file("extdata", "config_mythenquai.yml", package = "rOstluft.import")
config <- yaml::read_yaml(config_file)
import(config)
#> INFO  [23:08:54.217] Starte import 
#> INFO  [23:08:54.981] Download fehlende Dateien für den Zeitraum von 2022-03-13 bis 2022-03-19: https://tecdottir.herokuapp.com/measurements/mythenquai?startDate=2022-03-17&endDate=2022-03-18, https://tecdottir.herokuapp.com/measurements/mythenquai?startDate=2022-03-18&endDate=2022-03-19 
#> INFO  [23:08:56.070] Lese Datei: tmp/cache/seepolizei/mythenquai_2022-03-18.json 
#> INFO  [23:08:56.449] Schreibe importierte Daten in Datei: tmp/imported/seepolizei/2022/mythenquai_2022-03-18.rds 
#> INFO  [23:08:56.454] Lösche Cache Datei: tmp/cache/seepolizei/mythenquai_2022-03-18.json 
#> INFO  [23:08:56.458] Lese Datei: tmp/cache/seepolizei/mythenquai_2022-03-19.json 
#> INFO  [23:08:56.606] Schreibe importierte Daten in Datei: tmp/imported/seepolizei/2022/mythenquai_2022-03-19.rds 
#> INFO  [23:08:56.611] Lösche Cache Datei: tmp/cache/seepolizei/mythenquai_2022-03-19.json 
#> INFO  [23:08:56.614] Import beendet
```

``` yaml
# Konfiguration Zeitraum:
# to = lubridate::floor_date(lubridate::now(tz), floor_now) - lubridate::period(to_offset)
# from = to - lubridate::period(period)
# dates = seq(from, to, by = interval)
tz: "GMT"
floor_now: "day"
to_offset: "1 day"
period: "6 days"
interval: "1 day"

# Konfiguration Quelle und Ablage
source_typ: "curl"     # curl, copy
input_fn_tpl: "https://tecdottir.herokuapp.com/measurements/mythenquai?startDate={format(date - 1, '%Y-%m-%d')}&endDate=%Y-%m-%d"
cache_fn_tpl: "cache/seepolizei/mythenquai_%Y-%m-%d.json"
imported_fn_tpl: "imported/seepolizei/%Y/mythenquai_%Y-%m-%d.rds"

# verwendeter lokaler rOstluft Store
store_name: "rOstluft.import"

# Das Paket (Namespace), welches die Lesefunktion enthält muss aus R spezifischen
# Gründen separat angeben werden. Verwende NULL we
reading_function_ns: "rOstluft"
reading_function: "read_seepolizei_json"

# Allgemeines Verhalten
missing_files: "warn"
delete_cache: TRUE

# Curl Optionen. Mehr Infos unter folgenden Links:
# - https://jeroen.cran.dev/curl/reference/curl_options.html
# - https://curl.se/libcurl/c/curl_easy_setopt.html
# Beispiel für nltm Proxy + basic http auth
#curl_opts:
#  proxy: "proxy.server.loc:8080"
#  proxyauth: 8
#  proxyuserpwd: ":"
#  ssl_verifypeer: 0
#  httpauth: 1         
#  userpwd: "user:password"

# Zusätzliche HTTP Headers wenn curl verwendet wird. Beispielsweise ein JWT
# Token zur Authorisation
#curl_headers:
#  Authorization: "Bearer XXXXXXXXXXXXXXXXXX"

# Konfiguration der Normalisierung mit rOstluft::meta_apply
# Für jeden Eintrag unter Meta wird meta_apply einmal aufgerufen
meta_key: seepolizei
meta:
  -
    data_src: site
    data_dest: site
    meta_key: site_short
    meta_val: site
  -
    data_src: parameter
    data_dest: unit
    meta_key: parameter_original
    meta_val: unit
  -
    data_src: parameter
    data_dest: parameter
    meta_key: parameter_original
    meta_val: parameter
```
