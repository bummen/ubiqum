#### M3T3posKNNnew.R -- approach B: 
#
# - exclude variables with too low variability
# - model position (latitude, longitude) as numeric (integers)
# - check with validation set
# - prediction on waps (1st round) 
#   and 2nd round on waps+lon (for lat) and on waps+lat (for lon)
#
####

# load libraries ####
library(dplyr)
library(caret)

library(reshape2)
library(ggplot2)
library(raster) 

library(beepr)

# read data ####
## training and test set
trData = read.csv(
  file ="trainingData.csv", 
  header=T)

## validation set
vlData = read.csv(
  file ="validationData.csv", 
  header=T)

# pre-process data ####
## aux dataframes
### cols corresponding to waps are 1:520
trData.waps <- trData[,1:520]

# -0- # 
# _____to use for prediction
## replace 100's (no signal) 
## replace 100 by -110 in the main dataframe
trData[trData==100]<--110

vlData[vlData==100]<--110

# -0.1- # 
# _____type conversion of target variable (rounding)
## convert vars LATITUDE and LONGITUDE to integers
trData$LATITUDE  <- as.integer(trData$LATITUDE)
trData$LONGITUDE <- as.integer(trData$LONGITUDE)

vlData$LATITUDE  <- as.integer(vlData$LATITUDE)
vlData$LONGITUDE <- as.integer(vlData$LONGITUDE)


# -1- # 
# _____clean of empty rows and cols #
## keep only WASP cols that have NOT all values 100 (no signal) 
## -- get rid of the cols with no information: 55 cols
### make an index
ind.1 <- sapply(trData.waps, min) < 100
### select cols after index
trData.waps.1 <- trData.waps[,ind.1]
### drop the corresponding cols of the main dataframe:
### use the index of waps df (but add 9 extra cols TRUE at the end)
trData.1 <- trData[,c(ind.1,rep(TRUE,9))]

vlData.1 <- vlData[,c(ind.1,rep(TRUE,9))]

## keep only Measurement rows that have NOT all values 100 (no signal) 
## -- get rid of the rows with no information: 76
indR.1 <- apply(trData.waps,1, min) < 100

### select rows after index
trData.waps.1 <- trData.waps.1[indR.1,]
### drop the corresponding rows of the main dataframe: (76 rows)
### use the same index of waps rows
trData.1 <- trData.1[indR.1,]

# -2- #
# _____replace 100's (no signal) #
## replace 100 (no signal detected from wap) by NA to complete computations
trData.waps.2 <- trData.waps.1
trData.waps.2[trData.waps.1==100]<-NA
# replace 100 by -110 in the main dataframe --> done in step 0

# -3- #
## compute variance by variable
# varCol <- apply(trData.waps.2,2,var,na.rm=T)
# hist(varCol,breaks=175)
# sum(varCol < 75, na.rm=T) ## 212 (23 NA)

## keep only WAPS cols that have var > 75 -> varCut
### make an index
varCut <- 75
ind.3 <- sapply(trData.waps.2,var,na.rm=T) > varCut
ind.3[is.na(ind.3)] <- FALSE  ## Don't count NAs
### select cols after index
trData.waps.3 <- trData.waps.2[,ind.3]
### drop the corresponding cols of the main dataframe
trData.2 <- trData.1[,c(ind.3,rep(TRUE,9))]

vlData.2 <- vlData.1[,c(ind.3,rep(TRUE,9))]

# -3 bis- #
###drop the rows that are equal (f.ex. all NA)
trData.waps.3.dist <- distinct(trData.waps.3)

### drop the corresponding rows of the main dataframe ##
l <- length(trData.2)
ind <- duplicated(trData.2[,1:(l-9)])
trData.3 <- trData.2[!ind,]

### prepare next steps (shorten names)
trData.waps.3 <- trData.waps.3.dist
# dim(trData.3)
# dim(vlData.2)

# model training -- first round ####
# ___ model: KNN
set.seed(1112)

### training control:
#### none
trControl <- trainControl(method="none")

#### n-fold cross-validation
# trControl <- trainControl(method = "cv", number = 5) # training control: 5-fold CV
# tuneGrid <- expand.grid(k = c(1,3,10)) # grid <- expand.grid(k = c(1,2,3,4,5))

#### model parameters
tuneGrid <- data.frame(k=3) #### model KNN: k=3

### training data: trData.3
l <- length(trData.3)
trData.3m <- trData.3[,1:(l-9)]
trData.3m <- cbind(trData.3m, trData.3$LATITUDE, trData.3$LONGITUDE)
names(trData.3m)[l-9+1] <- "LATITUDE"
names(trData.3m)[l-9+2] <- "LONGITUDE"

### split test and training set: index intrain
intrain<-createDataPartition(y=trData.3$LATITUDE,p=0.95,list=FALSE)

## LATITUDE 
trData.3mLat <- trData.3[,1:(l-9)]
trData.3mLat <- cbind(trData.3mLat, trData.3$LATITUDE)
names(trData.3mLat)[l-9+1] <- "LATITUDE"

### split test and training set: trainData + testData 
trainData.3mLat <-trData.3mLat[intrain,]
testData.3mLat <-trData.3mLat[-intrain,]

### train model: knn(LATITUDE ~ .), data = trData.3m 
start_time <- Sys.time()
LatKNN <- train(
  LATITUDE ~ ., 
  data = trainData.3mLat,
  method = "knn",
  trControl = trControl,
  tuneGrid = tuneGrid
)
end_time <- Sys.time()
print(end_time - start_time)
beep();

## LONGITUDE
trData.3mLon <- trData.3[,1:(l-9)]
trData.3mLon <- cbind(trData.3mLon, trData.3$LONGITUDE)
names(trData.3mLon)[l-9+1] <- "LONGITUDE"

### split test and training set: trainData + testData 
trainData.3mLon <-trData.3mLon[intrain,]
testData.3mLon <-trData.3mLon[-intrain,]

### train model: knn(LONGITUDE ~ .), data = trData.3m 
start_time <- Sys.time()
LonKNN <- train(
  LONGITUDE ~ ., 
  data = trainData.3mLon,
  method = "knn",
  trControl = trControl,
  tuneGrid = tuneGrid
)
end_time <- Sys.time()
print(end_time - start_time)
beep();

# model training -- second round ####
# ___ model: KNN

## LATITUDE 

### split test and training set: trainData + testData 
trainData.3m <-trData.3m[intrain,]
testData.3m <-trData.3m[-intrain,]

### train model: knn(LATITUDE ~ .), data = trData.3m
start_time <- Sys.time()
LatKNN2 <- train(
  LATITUDE ~ ., 
  data = trainData.3m,
  method = "knn",
  trControl = trControl,
  tuneGrid = tuneGrid
)
end_time <- Sys.time()
print(end_time - start_time)
beep();

## LONGITUDE

### train model: knn(LONGITUDE ~ .), data = trData.3m 
start_time <- Sys.time()
LonKNN2 <- train(
  LONGITUDE ~ ., 
  data = trainData.3m,
  method = "knn",
  trControl = trControl,
  tuneGrid = tuneGrid
)
end_time <- Sys.time()
print(end_time - start_time)
beep();

# model evaluation ####

## explore results of the model
# print(LatKNN)
# print(LonKNN)
# 
print(LatKNN2)
print(LonKNN2)

## predictions -- prepare 2nd round

#### prediction: trData.3p

##### prediction on train data
# trData.3pLat <- trainData.3mLat
# trData.3pLon <- trainData.3mLon

##### prediction on test data
# trData.3p <- testData.3m
# trData.3pLat <- testData.3m
# trData.3pLon <- testData.3m

##### prediction on validation data 
trData.3p <- vlData.2    ## hier write predictions of both Lat and Lon
                         ## as predLat1 and predLon1
trData.3pLat <- vlData.2 ## -- write predictions of Lat as LATITUDE (overwriting)
trData.3pLon <- vlData.2 ## -- write predictions of Lon as LONGITUDE (overwriting)

### make predictions (predLat, predLon) to use during modeling

#### Lat: trData.3pLat
##### predict and write as factor (LATITUDE) in the prediction for Lon, trData.3pLon
start_time <- Sys.time()
trData.3pLat$LATITUDE <- predict(LatKNN, trData.3p)
end_time <- Sys.time()
print(end_time - start_time)
beep();

##### make a copy in the combined prediction as predicted Latitude 1
trData.3p$predLat1 <- trData.3pLat$LATITUDE

#### Lon: trData.3pLon
##### write as factor (LONGITUDE) in the prediction for Lat, trData.3pLat
start_time <- Sys.time()
trData.3pLon$LONGITUDE <- predict(LonKNN, trData.3p)
end_time <- Sys.time()
print(end_time - start_time)
beep();

##### make a copy in the combined prediction as predicted Longitude 1
trData.3p$predLon1 <- trData.3pLon$LONGITUDE

## prediction: -- 2nd round. 
## use predicted Lat in trData.3pLat and predicted Lon in trData.3pLon
## to predict Lon and Lat as predLon2 and predLat2 in trData.3p

## predict Lat: using predLon1 and Waps from trData.3pLon
start_time <- Sys.time()
trData.3p$predLat2 <- predict(LatKNN2, trData.3pLon)
end_time <- Sys.time()
print(end_time - start_time)
beep();

## predict Lon: using predLat1 and Waps from trData.3pLat
start_time <- Sys.time()
trData.3p$predLon2 <- predict(LonKNN2, trData.3pLon)
end_time <- Sys.time()
print(end_time - start_time)
beep();

## predict Lat: using predLon2 and Waps from trData.3pLon
trData.3pLon$LONGITUDE <- trData.3p$predLon2 
start_time <- Sys.time()
trData.3p$predLat3 <- predict(LatKNN2, trData.3pLon)
end_time <- Sys.time()
print(end_time - start_time)
beep();

## predict Lon: using predLat2 and Waps from trData.3pLat
# trData.3pLat$LATITUDE <- trData.3p$predLat2 
# start_time <- Sys.time()
# trData.3p$predLon3 <- predict(LonKNN2, trData.3pLat)
# end_time <- Sys.time()
# print(end_time - start_time)
# beep();

## compute errors
postResample(trData.3p$predLat1, trData.3p$LATITUDE)
postResample(trData.3p$predLon1, trData.3p$LONGITUDE)

postResample(trData.3p$predLat2, trData.3p$LATITUDE)
postResample(trData.3p$predLon2, trData.3p$LONGITUDE)

postResample(trData.3p$predLat3, trData.3p$LATITUDE)
# postResample(trData.3p$predLon3, trData.3p$LONGITUDE)

### --> best results: with predLat3 and predLon2

## Compute Errors: using predLat3 and predLon2

diffLAT <- abs(trData.3p$LATITUDE - trData.3p$predLat3)
diffLON <- abs(trData.3p$LONGITUDE - trData.3p$predLon2)

diffEUC <- sqrt(diffLON^2 + diffLAT^2)
hist(diffEUC, breaks=90, main='KNN k=3, varCut=75')

print("Metrics for KNN, k=3")

mean(diffEUC)
median(diffEUC)
max(diffEUC)

quantile(diffEUC, 0.75)
quantile(diffEUC, 0.90)
quantile(diffEUC, 0.95)
quantile(diffEUC, 0.99)

## plotting results ####

### write euclidian dist errors as a new col in the df prediction
vlData.p <- cbind(vlData.p, diffEUC)

### classificate errors in 4 classes: <5, <10, <20, > 20 error
### write as a new col in the df prediction
getEUCclass <- function(x) {
  if(x < 5) return(as.integer(5))
  if(x < 10) return(as.integer(10));
  if(x < 20) return(as.integer(20));
  if(x >= 20) return(as.integer(40));
  return(NA);
}
# clEUC <- sapply(diffEUC, getEUCclass)
# vlData.p <- cbind(vlData.p, diffEUC)
vlData.p <- vlData.p %>% mutate(clErr = sapply(diffEUC, getEUCclass))

qplot(LATITUDE, predLat, data=vlData.p, color = clErr)
qplot(LONGITUDE, predLon, data=vlData.p, color = clErr)

qplot(predLat, predLon, data=vlData.p, color = clErr)
qplot(LATITUDE, LONGITUDE, data=vlData.p, color = clErr)

# plot(predLat ~ predLon, col="red", data=vlData.p, pch=16)
# points(vlData.p$LATITUDE ~ vlData.p$LONGITUDE, col = "black", pch=4)

############################ tools ####

hist(vlData.2$PHONEID,breaks=25, xlim = c(1,25))
hist(trData.3$PHONEID,breaks=25, xlim = c(1,25))

hist(vlData.2$BUILDINGID, xlim = c(0,2))
hist(trData.3$BUILDINGID, xlim = c(0,2))

hist(vlData.2$FLOOR,breaks=4, xlim = c(0,4))
hist(trData.3$FLOOR,breaks=4, xlim = c(0,4))

### cols corresponding to waps are 1:520
l <- length(vlData.2)
vlData.2.waps <- vlData.2[,1:(l-9)]
l <- length(trData.3)
trData.3.waps <- trData.3[,1:(l-9)]

plot(raster(as.matrix(vlData.2.waps)),main="vlData.2.waps", useRaster=F)
plot(raster(as.matrix(trData.3.waps)),main="trData.3.waps", useRaster=F)


############################ results ####
# > postResample(trData.3p$predLon2, trData.3p$LONGITUDE)
# RMSE        Rsquared    MAE 
# 9.1364889   0.9943302   5.5707321 
# > postResample(trData.3p$predLat3, trData.3p$LATITUDE)
# RMSE        Rsquared    MAE 
# 8.159454    0.986735    5.126913 
# [1] "Metrics for KNN, k=3"
# > mean(diffEUC)
# [1] 8.431344
# > median(diffEUC)
# [1] 5.830952
# > max(diffEUC)
# [1] 76.46423
# > quantile(diffEUC, 0.75)
# 75% 
# 11.16043 
# > quantile(diffEUC, 0.90)
# 90% 
# 18.76462 
# > quantile(diffEUC, 0.95)
# 95% 
# 24.54604 
# > quantile(diffEUC, 0.99)
# 99% 
# 43.94166 