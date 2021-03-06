#####################################################################
##
## $Id: covar.R,v 1.7.2.8 2006/12/06 15:26:31 byandell Exp $
##
##     Copyright (C) 2006 Brian S. Yandell
##
## This program is free software; you can redistribute it and/or modify it
## under the terms of the GNU General Public License as published by the
## Free Software Foundation; either version 2, or (at your option) any
## later version.
##
## These functions are distributed in the hope that they will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## The text of the GNU General Public License, version 2, is available
## as http://www.gnu.org/copyleft or by writing to the Free Software
## Foundation, 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
##
##############################################################################
## Covariate routines:
##    covar.mean       vector of means of covariates (Internal)
##    covar.var        matrix of covariance of covariates (Internal)
##
##    qb.varcomp      matrix of covariate variance components by MCMC sample.
##    qb.meancomp     scatterplot matrix of grand mean and fixed covariates.
##                     (should spin off plot and summary methods)
##    qb.covar        xyplots of main effects by covariate grouped by chr.
##                     (note handling of zeros and covariate offset)
##    qb.confound      covariance of covariate with (pseudo)markers
##
##    The four external routines have plot, summary and print methods.
##
## NB: Would be nice to have histogram in middle of splom.
##
## Ideas for covariate:
## 
## Add covariate var to mainloci var in qb.scan.
## Allow a term for covar effect on variance components.
## Include covariate add and dom in plot.qb.effects.
## Need to add covariate names to bmapqtl element.
##############################################################################
covar.mean <- function(qbObject, adjust.covar, verbose = FALSE,
                       pheno.col = qb.get(qbObject, "pheno.col"))
{
  nfixcov <- qb.get(qbObject, "nfixcov")
  nrancov <- qb.get(qbObject, "nrancov")
  if(nfixcov + nrancov == 0) {
    return(numeric())
  }
  ## Covariate mean adjustment used for mean and main effects.
  if(is.null(qb.get(qbObject, "covar"))) {
    stop("no covar element in qb object", call. = FALSE,
            immediate. = TRUE)
  }
  else {
    ## Could use qb.get(qbObject, "fixcoef") and qb.get(qbObject, "yvalue") here.
    ## Recall that missing code used is 999.
    cross <- qb.cross(qbObject, genoprob = FALSE)
    covar.name <- names(cross$pheno)[qb.get(qbObject, "covar")]
    if(nfixcov > 0) {
      pheno.name <- names(cross$pheno)[pheno.col[1]]
      use.value <- cross$pheno[, pheno.name]
      use.value <- !is.na(use.value) & abs(use.value) != Inf
      tmp <- cross$pheno[, covar.name[seq(nfixcov)], drop = FALSE]
      covar.means <- unlist(lapply(tmp[use.value,, drop = FALSE],
                                   mean, na.rm = TRUE))
      covar.means <- c(covar.means, rep(0, nrancov))
    }
    else
      covar.mean <- rep(0, nrancov)
    names(covar.means) <- covar.name
  }

  if(!missing(adjust.covar)) {
    if(length(adjust.covar) > nfixcov + nrancov)
      adjust.covar <- adjust.covar[seq(nfixcov + nrancov)]
    else
      adjust.covar <- c(adjust.covar,
                        rep(NA, nfixcov + nrancov - length(adjust.covar)))
    tmp <- !is.na(adjust.covar)
    if(any(tmp))
      covar.means[tmp] <- adjust.covar[tmp]
  }
  
  if(any(abs(covar.means) > 10^-6) & verbose) {
    warning(paste("covariate adjustment(s):",
                  paste(covar.name[seq(nfixcov)], collapse = ","),
                  "*",
                  paste(round(covar.means[seq(nfixcov)], 3), collapse = ",")),
            call. = FALSE, immediate. = TRUE)
  }
  covar.means
}
##############################################################################
covar.var <- function(qbObject)
{
  ## This could be consolidated into two routines:
  ## covar.var: analog to covar.mean, with covariances for covariates.
  ## apply(qb.cov,1,sum) for use in qb.scan.
  
  nfixcov <- qb.get(qbObject, "nfixcov")
  if(nfixcov == 0) {
    return(numeric())
  }
  if(is.null(qb.get(qbObject, "covar"))) {
       stop("no covar element in qb object", call. = FALSE,
            immediate. = TRUE)
  }
  cross <- qb.cross(qbObject, genoprob = FALSE)
  covar.name <- names(cross$pheno)[qb.get(qbObject, "covar")[seq(nfixcov)]]
  stats::cov(as.matrix(cross$pheno[, covar.name]), use = "pair")
}
##############################################################################
qb.varcomp <- function(qbObject, scan = scans, aggregate = TRUE, ...)
{
  qb.exists(qbObject)
  
  ## Variance components for MCMC samples.

  ## Get scan components.
  scans <- c("main","epistasis","fixcov","rancov","GxE")
  scan <- scans[pmatch(tolower(scan), tolower(scans), nomatch = 0)]

  nfixcov <- qb.get(qbObject, "nfixcov")
  nrancov <- qb.get(qbObject, "nrancov")
  intcov <- qb.get(qbObject, "intcov")
  intcov <- check.intcov(intcov, nfixcov)

  if(!nfixcov)
    scan <- scan[scan != "fixcov"]
  if(!nrancov)
    scan <- scan[scan != "rancov"]
  if(!sum(intcov))
    scan <- scan[scan != "GxE"]
  if(!length(scan))
    stop("no elements for variance components")

  is.bc <- (qb.cross.class(qbObject) == "bc")

  ## Determine variance components to include.
  var1 <- "add"
  var2 <- "aa"
  if(!is.bc) {
    var1 <- c(var1,"dom")
    var2 <- c(var2,"ad","da","dd")
  }
  if(nfixcov + nrancov)
    covar.name <- names(qb.cross(qbObject, genoprob = FALSE)$pheno)[qb.get(qbObject, "covar")]
  iterdiag <- qb.get(qbObject, "iterdiag", ...)
  n.iter <- nrow(iterdiag)

  if(aggregate) {
    out <- matrix(NA, n.iter, length(scan))
    dimnames(out) <- list(NULL, scan)
  }
  else {
    outnames <- NULL
    if(any(scan == "main"))
      outnames <- var1
    if(any(scan == "epistasis"))
      outnames <- c(outnames, var2)
    if(any(scan == "fixcov")) {
      fix.name <- covar.name[seq(nfixcov)] 
      varnames <- outer(fix.name, fix.name, paste, sep = ".")
      rc <- row(varnames) >= col(varnames)
      diag(varnames) <- fix.name
      outnames <- c(outnames, varnames[rc])
    }
    if(any(scan == "rancov"))
      outnames <- c(outnames, covar.name[nfixcov + seq(nrancov)])
    if(any(scan == "GxE"))
      outnames <- c(outnames, paste(var1, "E", sep = "x"))
    out <- matrix(NA, n.iter, length(outnames))
    dimnames(out) <- list(NULL, outnames)
  }
  
  ## Main effect variance components.
  if(any(scan == "main")) {
    vars <- paste("var", var1, sep = "")
    if(aggregate)
      out[, "main"] <- apply(as.matrix(iterdiag[, vars]), 1, sum)
    else
      out[, var1] <- iterdiag[, vars]
  }
  if(any(scan == "epistasis")) {
    vars <- paste("var", var2, sep = "")
    if(aggregate)
      out[, "epistasis"] <- apply(as.matrix(iterdiag[, vars]), 1, sum)
    else
      out[, var2] <- iterdiag[, vars]
  }

  ## Covariates.
  if(nfixcov + nrancov & any(match(scan, c("fixcov","rancov"), nomatch = 0))) {
    covariate <- as.matrix(qb.get(qbObject, "covariates", ...))
    
    ## Fixed covariate variance components.
    if(nfixcov & any(scan == "fixcov")) {
      fix.name <- covar.name[seq(nfixcov)] 
      covs <- covar.var(qbObject)
      fix.comp <- apply(covariate[, seq(nfixcov), drop = FALSE],
                        1,
                        function(x, covs) c(covs * outer(x, x)),
                        covs)
      if(aggregate) {
        out[, "fixcov"] <- if(nfixcov == 1)
          fix.comp
        else
          matrix(apply(fix.comp, 2, sum), ncol(fix.comp), 1)
      }
      else {
        if(nfixcov == 1)
          out[, covar.name[1]] <- fix.comp
        else
          out[, varnames[rc]] <- t(fix.comp[rc, ])
      }
    }
    if(nrancov) {
      if(aggregate) {
        out[, "rancov"] <- apply(covariate[, nfixcov + seq(nrancov),
                                           drop = FALSE],
                                 1, sum)
      }
      else
        out[, covar.name[nfixcov + seq(nrancov)]] <-
          covariate[, nfixcov + seq(nrancov)]
    }
  }
  if(any(scan == "GxE")) {
    ## Could break down further by covariate, but probably not worth it.
    vars <- paste("env", var1, sep = "")
    if(aggregate)
      out[, "GxE"] <- apply(as.matrix(iterdiag[, vars]), 1, sum)
    else
      out[, paste(var1, "E", sep = "x")] <- iterdiag[, vars]
  }

  nout <- dimnames(out)[[2]]
  zout <- !apply(out, 2, function(x) all(x == 0))
  if(!sum(zout))
    stop("all variance components are zero")
  
  out <- as.matrix(out[, zout])
  dimnames(out) <- list(NULL, nout[zout])

  class(out) <- c("qb.varcomp", "matrix")
  attr(out, "cex") <- qb.cex(qbObject)
  out
}
##############################################################################
plot.qb.varcomp <- function(x, log = TRUE, percent = 5,
                             cex = attr.cex, ...)
{
  lattice::trellis.par.set(theme = lattice::col.whitebg(), warn = FALSE) ## white background

  attr.cex <- attr(x, "cex")
  x <- data.frame(x)

  if(log) {
    zero <- x <= 0
    minx <- min(x[!zero], na.rm = TRUE)
    x[zero] <- minx / 2
    x <- log10(x)
  }
  if(ncol(x) > 1) {
    print(lattice::splom(x, cex = cex,
                panel = function(x,y,...) {
                  lattice::panel.abline(h = 0, v = 0, ...,
                               col = "blue", lwd = 2, lty = 2)
                  lattice::panel.abline(v = stats::median(x, na.rm = TRUE), ...,
                               col = "red", lwd = 2)
                  lattice::panel.abline(v = stats::quantile(x,
                                 c(percent, 100 - percent) / 100),
                               ..., col = "red", lwd = 2, lty = 3)
                  lattice::panel.abline(h = stats::median(y, na.rm = TRUE), ...,
                               col = "red", lwd = 2)
                  lattice::panel.abline(h = stats::quantile(y,
                                 c(percent, 100 - percent) / 100),
                               ..., col = "red", lwd = 2, lty = 3)
                  lattice::panel.splom(x,y,...)
                },
                diag.panel=function(x,...) {
                  d <- stats::density(x)
                  ry <- range(d$y, finite = TRUE)
                  rx <- range(x, finite = TRUE)
                  r <- diff(rx) / diff(ry)
                  lattice::panel.xyplot(d$x, rx[1] + r * d$y, type = "l", lwd = 2)
                  lattice::diag.panel.splom(x,...)
                }))
  }
  else {
    form <- stats::formula(paste("~", names(x)))
    print(lattice::densityplot(form, x, ...))
  }
  invisible()
}
##############################################################################
summary.qb.varcomp <- function(object, ...)
{
  ## Really want mean and 5%, 95%
  apply(object, 2, summary)
}
##############################################################################
print.qb.varcomp <- function(x, ...) print(summary(x, ...))
##############################################################################
qb.meancomp <- function(qbObject, adjust.covar = NA, ...)
{
  qb.exists(qbObject)
  
  ## Mean components: grand mean and covariates.

  ## Get grand mean.
  data <- as.matrix(qb.get(qbObject, "iterdiag", ...)$mean)
  dimnames(data) <- list(NULL, "grand.mean")

  nfixcov <- qb.get(qbObject, "nfixcov")
  if(nfixcov) {
    ## Set up mean adjusted for covariates.
    covar.means <- covar.mean(qbObject, adjust.covar, ...)[seq(nfixcov)]
    covar.name <- names(covar.means)

    ## Get Covariate main effect and grand mean.
    data <- cbind(data,
                  as.matrix(qb.get(qbObject, "covariates", ...))[, seq(nfixcov)])
    dimnames(data) <- list(NULL, c("grand.mean", covar.name))

    if(any(abs(covar.means) > 10^-6)) {
      for(i in covar.name)
        data[, "grand.mean"] <- data[, "grand.mean"] +
          covar.means[i] * data[, i]
    }
  }
  class(data) <- c("qb.meancomp", "matrix")
  attr(data, "cex") <-  qb.cex(qbObject)
  attr(data, "nfixcov") <- qb.get(qbObject, "nfixcov")
  data
}
##############################################################################
print.qb.meancomp <- function(x, ...) print(summary(x, ...))
##############################################################################
summary.qb.meancomp <- function(object, percent = 5, ...)
{
  apply(as.matrix(object), 2, function(x)
        c(mean = mean(x), stats::quantile(x, c(percent, 100 - percent) / 100)))
}
##############################################################################
plot.qb.meancomp <- function(x,
                          covar = if(nfixcov) seq(nfixcov) else 0,
                          percent = 5, cex = attr(x, "cex"),
                          ...)
{
  ## Rename: qb.mean.
  lattice::trellis.par.set(theme = lattice::col.whitebg(), warn = FALSE) ## white background

  nfixcov <- attr(x, "nfixcov")

  ## Subset to covariates to plot.
  nx <- dimnames(x)[[2]]
  px <- as.data.frame(x[,1 + unique(c(0, covar))])
  names(px) <- nx[1 + unique(c(0, covar))]
  
  if(nfixcov) {
    ## Scatterplot Matrix using lattice library.
    print(lattice::splom(px, cex = cex,
                panel = function(x,y,...) {
                  lattice::panel.abline(h = 0, v = 0, ...,
                               col = "blue", lwd = 2, lty = 2)
                  lattice::panel.abline(v = stats::median(x, na.rm = TRUE), ...,
                               col = "red", lwd = 2)
                  lattice::panel.abline(v = stats::quantile(x,
                                 c(percent, 100 - percent) / 100),
                               ..., col = "red", lwd = 2, lty = 3)
                  lattice::panel.abline(h = stats::median(y, na.rm = TRUE), ...,
                               col = "red", lwd = 2)
                  lattice::panel.abline(h = stats::quantile(y,
                                 c(percent, 100 - percent) / 100),
                               ..., col = "red", lwd = 2, lty = 3)
                  lattice::panel.splom(x,y,...)
                },
                diag.panel=function(x,...) {
                  d <- stats::density(x)
                  ry <- range(d$y, finite = TRUE)
                  rx <- range(x, finite = TRUE)
                  r <- diff(rx) / diff(ry)
                  lattice::panel.xyplot(d$x, rx[1] + r * d$y, type = "l", lwd = 2)
                  lattice::diag.panel.splom(x,...)
                }))
  }
  else {
    form <- stats::formula(paste("~", names(px)))
    print(lattice::densityplot(form, px, ...))
  }
  invisible()
}
##############################################################################
qb.covar <- function(qbObject, element = "add", covar = 1,
                     adjust.covar = NA,
                      chr, ...)
{
  qb.exists(qbObject)
  
  qbname <- deparse(substitute(qbObject))
  
  if(!missing(chr))
    qbObject <- subset(qbObject, chr = chr)

  ## Set up mean adjusted for covariates.
  covar.means <- covar.mean(qbObject, adjust.covar, ...)
  covar.name <- names(covar.means)

  ## Get GxE fixed effects for Covariate covar.
  gbye <- qb.get(qbObject, "gbye", ...)

  ## Get mainloci element.
  mainloci <- qb.get(qbObject, "mainloci", ...)
  data <- data.frame(main = mainloci[[element]])

  ## Get GxE samples, match to mainloci.
  for(i in seq(qb.get(qbObject, "nfixcov"))) {
    tmp <- gbye[gbye$covar == i, ]
    same <- match(paste(tmp$niter, tmp$chrom, tmp$locus, sep = ":"),
                  paste(mainloci$niter, mainloci$chrom, mainloci$locus,
                        sep = ":"))
    tmp <- tmp[[element]]

    ## Adjust main by covariate.
    if(covar.means[i] != 0)
      data$main[same] <- data$main[same] + covar.means[i] * tmp
    if(covar == i) {
      data[[covar.name[covar]]] <- rep(0, nrow(mainloci))
      data[[covar.name[covar]]][same] <- tmp
    }
  }
  rm(same)
  gc()
  names(data) <- c(paste("main", element, sep = "."),
                          paste(covar.name[covar], element, sep = "."))
  
  ## Use chr names from cross qbObject.
  chrnames = names(qb.cross(qbObject, genoprob = FALSE)$geno)
  data$chr <- ordered(chrnames[mainloci$chrom],
                      chrnames[sort(unique(mainloci$chrom))])
  class(data) <- c("qb.covar", "data.frame")
  attr(data, "cex") <-  qb.cex(qbObject)
  data
}
##############################################################################
summary.qb.covar <- function(object, percent = 5, digits = 3, ...)
{
  percent <- c(percent, 100 - percent)
  znames <- c("mean", paste(percent, "%", sep = ""))
  percent <- percent / 100
  chrs <- levels(object[, "chr"])

  tmpfn <- function(x)
    c(mean = mean(x), stats::quantile(x, percent))

  
  tmpfn2 <- function(x,y) {
    z <- matrix(unlist(tapply(x, y, tmpfn)), 3)
    dimnames(z) <- list(znames, chrs)
    z
  }

  plotted <- dimnames(object)[[2]][1:2]
  out <- matrix(0, length(chrs), 8)
  dimnames(out) <- list(chrs,
                        c(t(outer(plotted, znames, paste, sep = ".")),
                          "correlation", "p-value"))
  for(i in plotted) {
    out[, paste(i, znames, sep = ".")] <-
      t(tmpfn2(object[, i], object[, "chr"]))
  }
  for(i in chrs) {
    ii <- (object[, "chr"] == i)
    tmp <- stats::cor.test(object[ii, 1], object[ii, 2])
    out[i, "correlation"] <- tmp$estimate
    out[i, "p-value"] <- tmp$p.value
  }
  signif(out, digits)
}
##############################################################################
print.qb.covar <- function(x, ...) print(summary(x, ...))
##############################################################################
plot.qb.covar <- function(x, percent = 5, cex = attr(x, "cex"),
                           include.zero = TRUE, ...)
{
  ## Lattice xyplot.
  lattice::trellis.par.set(theme = lattice::col.whitebg(), warn = FALSE) ## white background

  ## Set up formula for xyplot
  tmp <- names(x)
  form <- stats::formula(paste(tmp[2], "~", tmp[1], "|", tmp[3]))
  
  print(lattice::xyplot(form, x, cex = cex,
               panel = function(x,y,...) {
                 lattice::panel.abline(h = 0, v = 0,...,
                              col = "blue", lwd = 2, lty = 2)
                 if(include.zero) {
                   x0 <- x
                   y0 <- y
                 }
                 else {
                   x0 <- x[x != 0]
                   y0 <- y[y != 0]
                 }
                 lattice::panel.abline(v = mean(x0, na.rm = TRUE), ...,
                              col = "red", lwd = 2)
                 lattice::panel.abline(h = mean(y0, na.rm = TRUE), ...,
                              col = "red", lwd = 2)
                 lattice::panel.abline(v = stats::quantile(x0,
                                c(percent, 100 - percent) / 100),
                              ..., col = "red", lwd = 2, lty = 3)
                 lattice::panel.abline(h = stats::quantile(y0,
                                c(percent, 100 - percent) / 100),
                              ..., col = "red", lwd = 2, lty = 3)
                 lattice::panel.xyplot(x,y,...)
               }))
  invisible()
}
##############################################################################
qb.confound <- function(qbObject, covar = 1)
{
  qb.exists(qbObject)
  
  cross <- qb.cross(qbObject)
  grid <- pull.grid(qbObject, cross = cross)
  is.f2 <- class(cross)[1] == "f2"

  if(is.null(cross$geno[[1]]$prob))
    stop("First first run qb.genoprob on cross object")

  covariate <- cross$pheno[, qb.get(qbObject, "covar")[covar]]
  covar.name <- names(cross$pheno)[qb.get(qbObject, "covar")[covar]]
  
  ## Get expected values of pseudomarkers.
  pseudomark <- matrix(unlist(lapply(cross$geno, function(x)
                                     {
                                       nc <- dim(x$prob)[3]
                                       (x$prob[,,nc] - x$prob[,,1]) / (4 - nc)
                                     })), qtl::nind(cross))

  ## Kludge to get subset of pseudomarkers. Fix better later.
  ## For instance create pull.prob?
  tmp <- qbObject
  tmp$subset <- NULL
  gridfull <- pull.grid(tmp)
  tmp <- match(paste(grid$chr, grid$pos, sep = "."),
               paste(gridfull$chr, gridfull$pos, sep = "."))
  pseudomark <- pseudomark[, tmp]

  grid$chr <- names(cross$geno)[grid$chr]
  grid$coradd <- stats::cor(pseudomark, covariate, use = "pairwise.complete.obs")
  if(is.f2)
    grid$cordom <- stats::cor(apply(pseudomark, 2,
                             function(x) (x - mean(x, na.rm = TRUE)) ^ 2),
                       covariate, use = "pairwise.complete.obs")
  class(grid) <- c("qb.confound", "scanone", "data.frame")
  attr(grid, "cross.class") <- qb.cross.class(qbObject)
  attr(grid, "n.cov") <- sum(!is.na(covariate))
  attr(grid, "covar") <- covar.name
  grid
}  
##############################################################################
print.qb.confound <- function(x, ...)
{
  print(summary(x, ...))
}
##############################################################################
summary.qb.confound <- function(object, ...)
{
  class(object) <- c("scanone", "data.frame")
  print(summary(object, ...))
}
##############################################################################
plot.qb.confound <- function(x,
                              ylim = range(c(x[, 2 + curves]), na.rm = TRUE),
                              main = main.title,
                              ...)
{
  n.cov <- attr(x, "n.cov")
  covar.name <- attr(x, "covar")
  
  curves <- seq(1 + (attr(x, "cross.class") == "f2"))
  col <- c("blue", "red")[curves]
  adddom <- c("add", "dom")[curves]
  
  ## Pretty main title.
  main.title = paste("correlation of", covar.name, "with (pseudo)markers\n",
  paste(adddom, col, sep = " = ", collapse = ", "))

  ## Change y label to correlation and change class of x to scanone.
  names(x) <- c("chr","pos", rep("correlation", length(curves)))
  class(x) <- c("scanone", "data.frame")
  
  plot(x, lodcolumn = curves, col = col, ylim = ylim, main = main, ...)
  graphics::abline(h = 0, lty = 3, lwd = 2)
  
  ## Add SE lines based on correlation.
  tmpfn <- function(x,n) {
    z <- x / sqrt(n - 3)
    (exp(2 * z) - 1) / (exp(2 * z) + 1)
  }
  graphics::abline(h = tmpfn(-1.96, n.cov), lty = 2, lwd = 2)
  graphics::abline(h = tmpfn( 1.96, n.cov), lty = 2, lwd = 2)
  invisible()
}  
