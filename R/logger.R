.onLoad <- function(...){
  assign(
    "lg",  # the recommended name for a logger object
    lgr::get_logger(name = "rOstluft.import"),  # should be the same as the package name
    envir = parent.env(environment())
  )
}
