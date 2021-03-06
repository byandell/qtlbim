\name{qbExample}
\alias{qbExample}
\docType{data}
\title{MCMC sample for fake BC example}
\description{
Retrieve or recreate MCMC samples used in qtlbim.pdf document and demos.
}
\usage{data(qbExample)}
\details{
  This example is used in vignettes and demos.
  See vignette \code{qtlbim.pdf} or see \code{qtlbim.Rnw} in doc folder of package.
}
\seealso{
\code{\link{qb.genoprob}}, \code{\link{qb.mcmc}}, \code{\link{qb.sim.cross}}
}
\examples{
data(qbExample)
summary(qbExample)

\dontrun{
## Fake BC Example.
set.seed(1234)
cross <- qb.sim.cross(len = rep(60,3), n.mar = 7, eq.spacing =FALSE,
       n.ind = 100, type = "bc", ordinal = c(0.3,0.3,0.2,0.2),
       missing.geno = 0.03, missing.pheno = 0.03,
       qtl.pos = rbind(qtl.1=c(chr=1,pos=15),qtl.2=c(1,45),qtl.3=c(2,12),qtl.4=c(3,15)),
       qtl.main = rbind(main.1=c(qtl=1,add=1.5),main.2=c(2,0),
         main3=c(3,-1),main4=c(4,0)),
       qtl.epis = rbind(epis1=c(qtl.a=2,qtl.b=3,aa=-2),
         epis2=c(2,4,3)),
       covariate = c(fix.cov=0.5,ran.cov=0.07),
       gbye = rbind(GxE.1=c(qtl=3,add=2)))
summary(cross$qtl)
cross <- qb.genoprob(cross, step=2)
qbExample <- qb.mcmc(cross, pheno.col = 3, rancov = 2, fixcov = 1,
                     chr.nqtl = rep(3, qtl::nchr(cross)), intcov = 1, seed = 1216,
                     interval = rep(10,3), n.iter = 1000, n.thin = 20)

save("qbExample", file = "qbExample.RData")
}
}
\keyword{datasets}
