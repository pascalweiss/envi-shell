# Set this to where Spark is installed
Sys.setenv(SPARK_HOME="home/pascal/spark-1.6.0")
# This line loads SparkR from the installed directory
.libPaths(c(file.path(Sys.getenv("SPARK_HOME"), "R", "lib"), .libPaths()))
library(SparkR)
sc <- sparkR.init(master="local")
