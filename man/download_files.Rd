% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/functions.R
\name{download_files}
\alias{download_files}
\title{Herunterladen der Inputdateien mit \code{\link[curl:curl_download]{curl::curl_download()}}}
\usage{
download_files(df, config, ...)
}
\arguments{
\item{df}{Dataframe mit Liste der Dateien}

\item{config}{Konfiguration für gesamten import}

\item{...}{aktuell nicht gebraucht, eventuell in Zukunft zur Überschreibung von config Werten}
}
\value{
invisible(NULL)
}
\description{
Filtert den Dataframe basieren auf den bereits vorhanden Dateien im Cache und importierten
}
