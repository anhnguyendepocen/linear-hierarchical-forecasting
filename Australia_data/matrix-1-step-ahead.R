library(tidyverse)
library(hts)
source("olsfc.R")
library(Matrix)
library(reshape)

TourismData <-ts(read.csv("TourismData_v3.csv", header = TRUE)[-c(1,2)],start=1,frequency =12)
ausgts <- gts(TourismData, characters = list(c(1, 1, 1), 3),
              gnames = c("State", "Zone", "Region", "Purpose","State x Purpose", "Zone x Purpose"))
k<-24
n<-nrow(TourismData)
train_tourist <-window(ausgts,start = c(1, 1),end = c(1, (n-k)))
validation_tourist <-window(ausgts,start = c(1, ((n-k)+1)),end = c(1, n))
ally <- aggts(ausgts)


## computing predictors (trend, dummy seasonality, lags) for each series
Xmat<-list()
freq <-12
maxlag <- 12
ally.final <- as.list(ally) 
Xmatrix<-function(X){
  X<-as.vector(X)
  intercept <- rep(1, length(X))
  trend<-seq(NROW(X))
  season<-forecast::seasonaldummy(ts(X,frequency = freq))
  Xlag<-quantmod::Lag(X,k=1:maxlag)
  X_mat<-cbind.data.frame(intercept,trend,season,Xlag)
  Xmat[[length(Xmat)+1]] <- X_mat 
}

Xmat.final <- lapply(ally.final, Xmatrix)

as.matrix <- Matrix::as.matrix
t <- Matrix::t
solve <- Matrix::solve
diag <- Matrix::diag

## empty matrix for the forecasts
result.fore <- matrix(NA, nrow = k, ncol = NCOL(ally))
## for loops for computing rolling base forecasts
for(i in 1:k){
  Xmat.final.train <- lapply(Xmat.final, function(x)x[1:((n - k) + (i - 1)),])
  Xmat.final.test <- lapply(Xmat.final, function(x)x[(n - k) + i,])
  mat <- Matrix::bdiag(lapply(Xmat.final.train, function(x){as.matrix(na.omit(x))}))
  mat <- as(mat, 'dgCMatrix')
  mat.inverse <- Matrix::solve(t(mat)%*%mat)
  mat.inverse <- as(mat.inverse, 'dgCMatrix')
  ally.train <- ally[1:((n - k) + (i - 1)),]
  y.final <- as.matrix(melt(ally.train[-c(1:maxlag),])$value)
  y.final <- as(y.final, 'dgCMatrix')
  coeff <- (mat.inverse %*%t(mat))%*%y.final
  coeff <- as(coeff, 'dgCMatrix')
  mat.test <- Matrix::bdiag(lapply(Xmat.final.test, function(x){as.matrix(na.omit(x))}))
  mat.test <- as(mat.test, 'dgCMatrix')
  base.fore <- mat.test%*%coeff
  result.fore [i,] <- as.vector(base.fore) 
}


gmat <- GmatrixG(ausgts$groups)
smatrix <- as((SmatrixM(gmat)), 'dgCMatrix')
lambda <- as(diag(rowSums(smatrix)), 'dgCMatrix')

rec.adj.lambda <- as.matrix(smatrix%*%solve(t(smatrix)%*%solve(lambda)%*%smatrix)%*%t(smatrix)%*%solve(lambda))

## computing reconciled forecasts
fr.1 <- matrix(NA, nrow = k, ncol = ncol(ally))

for(i in 1:nrow(result.fore)){
  f.1 <- matrix(result.fore[i,], ncol = 1, nrow = ncol(result.fore))
  fr.1 [i,] <- rec.adj.lambda %*% f.1
}


