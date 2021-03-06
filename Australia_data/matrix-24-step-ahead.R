library(hts)
source("olsfc.R")
library(Matrix)
library(reshape)

TourismData1 <-read.csv("TourismData_v3.csv", header = TRUE)[-c(1,2)]
k<-24
n1<-nrow(TourismData1)


Xmat<-list()
freq <-12
nolag <- c(1,12)
maxlag <- 12

## function for computing predictors (trend, dummy seasonality, lags) for each series
Xmatrix<-function(X){
  X<-as.vector(X)
  intercept <- rep(1, length(X))
  trend1<-seq(NROW(X))
  trend2<-(seq(NROW(X)))^2
  season<-forecast::seasonaldummy(ts(X,frequency = freq))
  Xlag<-quantmod::Lag(X,k= nolag)
  X_mat<-cbind.data.frame(intercept, trend1, trend2, season, Xlag)
  Xmat[[length(Xmat)+1]] <- X_mat 
}

as.matrix <- Matrix::as.matrix
t <- Matrix::t
solve <- Matrix::solve
diag <- Matrix::diag


TourismData <- head(TourismData1, (n1-k))
## empty matrix for the forecasts
result.fore <- matrix(NA, nrow = k, ncol = 555)
base.fore <- c()

## for loop for computing base forecasts
for(i in 1:k){
  if(length(base.fore) == 0)
    TourismData <- TourismData
  else
    TourismData[nrow(TourismData),] <- tail(as.vector(base.fore),304)
  TourismData <- ts(rbind(TourismData, TourismData1[((n1-k)+i),]), start = 1, frequency = 12)
  ausgts <- gts(TourismData, characters = list(c(1, 1, 1), 3),
                gnames = c("State", "Zone", "Region", "Purpose","State x Purpose", "Zone x Purpose"))
  n <- nrow(TourismData)
  ally <- aggts(ausgts)
  Xmat.final <- lapply(as.list(ally), Xmatrix)
  Xmat.final.train <- lapply(Xmat.final, function(x)x[1:((n - 1) + (1 - 1)),])
  Xmat.final.test <- lapply(Xmat.final, function(x)x[(n - 1) + 1,])
  mat <- Matrix::bdiag(lapply(Xmat.final.train, function(x){as.matrix(na.omit(x))}))
  mat <- as(mat, 'dgCMatrix')
  mat.inverse <- Matrix::solve(t(mat)%*%mat)
  mat.inverse <- as(mat.inverse, 'dgCMatrix')
  ally.train <- ally[1:(n - 1),]
  y.final <- Matrix::as.matrix(melt(ally.train[-c(1:maxlag),])$value)
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
fr.24 <- matrix(NA, nrow = k, ncol = ncol(ally))
for(i in 1:nrow(result.fore)){
  f.24 <- matrix(result.fore[i,], ncol = 1, nrow = ncol(result.fore))
  fr.24 [i,] <- rec.adj.lambda %*% f.24
}


