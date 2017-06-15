##' Create recon usb stick
##'
##' @title Create recon usb stick
##' @param path Path to download things to
##' @param progress Print a progress bar for each downloaded file
##' @export
pack <- function(path, progress = TRUE) {
  if (!file.exists(path) || !file.info(path)$isdir) {
    stop("'path' must be an existing directory")
  }
  cfg <- nomad_config(path)

  packages_file <-
    file.path(path, cfg$packages %||% "packages.txt")
  package_sources_file <-
    file.path(path, cfg$package_sources %||% "package_sources.txt")
  if (!file.exists(packages_file)) {
    stop(sprintf("Did not find '%s' within '%s'",
                 basename(packages_file), path))
  }
  packages <- filter_comments(readLines(packages_file))

  if (file.exists(package_sources_file)) {
    spec <- filter_comments(readLines(package_sources_file))
    package_sources <- provisionr::package_sources(spec = spec)
  } else {
    package_sources <- NULL
  }

  r_version <- cfg$r_version %||% as.character(getRversion())
  if (length(r_version) != 1L) {
    ## The trick here would be to support just looping over versions
    ## at this point I think.
    stop("Not yet supported")
  }
  suggests <- cfg$suggests
  target <- cfg$target %||% "ALL"
  target_includes_windows <- target %in% c("ALL", "windows")

  ## Then we start the fun part:
  provisionr::download_cran(packages, path, r_version, target, suggests,
                            package_sources, progress)

  path_extra <- file.path(path, "extra")
  if (cfg$r) {
    download_r(path_extra, target, r_version, progress = progress)
  }
  if (cfg$rstudio) {
    download_rstudio(path_extra, target, progress = progress)
  }
  if (cfg$rtools && target_includes_windows) {
    download_rtools(path_extra, r_version, progress = progress)
  }
  if (cfg$git && target_includes_windows) {
    download_git(path_extra, progress = progress)
  }

  path
}

filter_comments <- function(x) {
  x[!grepl("^\\s*(#.*)?$", x)]
}

nomad_config <- function(path) {
  ret <- list(r_version = NULL,
              target = NULL,
              suggests = FALSE,
              package_list = NULL,
              package_sources = NULL,
              ## Extras:
              git = TRUE,
              r = TRUE,
              rstudio = TRUE,
              rtools = TRUE)
  file <- file.path(path, "nomad.yml")
  if (file.exists(file)) {
    d <- yaml_read(file)
    extra <- setdiff(names(d), names(ret))
    if (length(extra) > 0L) {
      stop(sprintf("Unknown keys in %s: %s",
                   file, paste(extra, collapse = ", ")))
    }
    ## TODO: there could always be a bunch of work sanitising the
    ## inputs here.  This is pretty minimal:
    fieldname <- function(x) {
      sprintf("%s:%s", basename(file), x)
    }
    assert_character_or_null(d$r_version, fieldname("r_version"))
    assert_character_or_null(d$target, fieldname("target"))
    assert_scalar_logical_or_null(d$suggests, fieldname("suggests"))
    assert_character_or_null(d$package_list, fieldname("package_list"))
    assert_character_or_null(d$package_sources, fieldname("package_sources"))
    assert_scalar_logical_or_null(d$git, fieldname("git"))
    assert_scalar_logical_or_null(d$r, fieldname("r"))
    assert_scalar_logical_or_null(d$rstudio, fieldname("rstudio"))
    assert_scalar_logical_or_null(d$rtools, fieldname("rtools"))
    ret <- modifyList(ret, d[lengths(d) > 0])
  }
  ret
}