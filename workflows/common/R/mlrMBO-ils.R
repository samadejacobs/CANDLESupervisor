
  #mlrMBO EMEWS Algorithm Wrapper
  # ILS: ???

  emews_root <- Sys.getenv("EMEWS_PROJECT_ROOT")
  if (emews_root == "") {
    r_root <- getwd()
  } else {
    r_root <- paste0(emews_root, "/../common/R")
  }
  wd <- getwd()
  setwd(r_root)

  source("mlrMBO_utils.R")

  # EQ/R based parallel map
  parallelMap2 <- function(fun, ...,
                           more.args = list(),
                           simplify = FALSE,
                           use.names = FALSE,
                           impute.error = NULL,
                           level = NA_character_,
                           show.info = NA){
    st = proc.time()

    #For wrapFun do this: initdesign
    if (deparse(substitute(fun)) == "wrapFun"){
      dots <- list(...)
      string_params <- elements_of_lists_to_json(dots[[1L]])
      # print(dots)
      # print(paste0("parallelMap2 called with list_param: ",string_params))
      # print(paste("parallelMap2 called with list size:", length(string_params)))
      OUT_put(string_params)
      string_results = IN_get()
      print(paste0("parallelMap2 results: ", string_results))

      st = proc.time() - st

      # Assumes results are in the form a;b;c
      # Note: can also handle vector returns for each,
      # i.e., a,b;c,d;e,f
      res <- string_to_list_of_vectors(string_results)
      print(paste0("parallelMap2 result count: ", length(res)))
      # using dummy time
      return(result_with_extras_if_exist(res,st[3]))
    }
    # For all other values of deparse(substitute(fun)) eg. proposePointsByInfillOptimization, doBaggingTrainIteration etc.
    else{
      return(pm(fun, ..., more.args = more.args, simplify = simplify, use.names = use.names, impute.error = impute.error,
                level = level, show.info = show.info))
    }
  }

  require(parallelMap)
  require(jsonlite)

  pm <- parallelMap

  unlockBinding("parallelMap", as.environment("package:parallelMap"))
  assignInNamespace("parallelMap", parallelMap2, ns="parallelMap", envir=as.environment("package:parallelMap"))
  assign("parallelMap", parallelMap2, as.environment("package:parallelMap"))
  lockBinding("parallelMap", as.environment("package:parallelMap"))

  library(mlrMBO)
  library(randomForest)

  # dummy objective function
  simple.obj.fun = function(x){}

  main_function <- function(max.budget = 110,
                            # max.iterations is not used
                            max.iterations = 10,
                            # design.size is ignored
                            design.size=10,
                            propose.points=10,
                            restart.file) {

    ptm <- proc.time()

    print("Using randomForest")
    surr.rf = makeLearner("regr.randomForest", predict.type = "se",
                          fix.factors.prediction = TRUE,
                          mtry = 8,
                          se.method = "jackknife",
                          se.boot = 2,
                          ntree=500)
    ctrl = makeMBOControl(n.objectives = 1,
                          propose.points = propose.points,
                          trafo.y.fun = makeMBOTrafoFunction('log', log),
                          impute.y.fun = function(x, y, opt.path, ...) .Machine$double.xmax )
    ctrl = setMBOControlTermination(ctrl, max.evals = propose.points+1)#, iters = max.iterations)

    ctrl = setMBOControlInfill(ctrl,
                              crit = makeMBOInfillCritCB(),
                              opt.restarts = 1,
                              opt.focussearch.points = 1000)

    chkpntResults<-NULL
    # TODO: Make this an argument
    restartFile<-restart.file
    if (file.exists(restart.file)) {
      print(paste("Loading restart:", restart.file))

      nk<-100
      dummydf<-generateDesign(n = nk, par.set = getParamSet(obj.fun))
      pids <- names(dummydf)
      dummydf<-cbind("y"=1.0,dummydf)

      #rename first column and reorder
      res<-read.csv(restart.file)
      cnames<-names(res)
      names(res)<-cnames
      # print(names(res))
      # print(names(dummydf))
      #Check if names are different, print difference and quit

      res<-subset(res, select=names(dummydf))
      res<-rbind(dummydf,res)
      res<-res[-c(1:nk),] # remove the dummy
      rownames(res)<-NULL
      chkpntResults<-res
    } else if (restart.file == "DISABLED") {
      print("Not a restart.")
    } else {
      print(paste0("Restart file not found: '", restart.file, "'"))
      print("Aborting!")
      quit()
    }

    if (is.null(chkpntResults)){
      par.set = getParamSet(obj.fun)

      ## represent each discrete value once
      # get the maximum number of variables
      max_val_discrete = 0
      index=0

      for (v in par.set$pars) {
        if (v$type == "discrete"){
          index=index+1
          i = 0
          for (val in v$values){
            i=i+1
          }
          if (max_val_discrete < i){
            max_val_discrete = i
          }
        }
      }
      # each discrete variable should be represented once, else optimization will fail
      # this checks if design size is less than max number of discrete values
      if (design.size < max_val_discrete){
        print("Aborting! design.size is less than the discrete parameters specified")
        quit()
      }

      design = generateDesign(n = propose.points, par.set)

      # this loop modifies the top max_val_discrete designs (design) to have each discrete value represented once
      i = 0
      for (v in par.set$pars){
        i=i+1
        if (v$type == "discrete"){
          index=0
          for (val in v$values){
            index=index+1
            design[[i]][index] = val
          }
        }
      }
    } else {
      design = chkpntResults
    }

  itr <- 0
  max_itr <- round(max.budget/propose.points)

  configureMlr(show.info = FALSE, show.learner.output = TRUE, on.learner.warning = "quiet")
  time <-(proc.time() - ptm)
  res = mbo(obj.fun, design = design, learner = surr.rf, control = ctrl, show.info = TRUE)
  itr_res<-as.data.frame(res$opt.path)
  itr_res<-cbind(itr_res, stime = as.numeric(time[3]))
  all_res <-itr_res
  itr <- itr + 1
  par.set = getParamSet(obj.fun)
  par.set0<-par.set


  #iterative phase starts
  while (nrow(all_res) < max.budget){
    time <-(proc.time() - ptm)
    print(sprintf("nevals = %03d; itr = %03d; time = %5.5f;", nrow(all_res), itr, as.numeric(time[3])))
    min.index<-which(itr_res$y==min(itr_res$y))

    par.set.t = par.set0
    pars = par.set.t$pars
    lens = getParamLengths(par.set.t)
    k = sum(lens)
    pids = getParamIds(par.set.t, repeated = TRUE, with.nr = TRUE)

    snames = c("y", pids)
    reqDF = subset(itr_res, select = snames, drop =TRUE)
    bestDF <- reqDF[min.index,]
    print("reqDF")
    print(nrow(reqDF))
    print(summary(reqDF))

    print("itr-rf")
    train.model <- randomForest(log(y) ~ ., data=reqDF, ntree=10000, keep.forest=TRUE, importance=TRUE)
    var.imp <- importance(train.model, type = 1)
    #var.imp[which(var.imp[,1] < 0),1]<-0
    index <- sort(abs(var.imp[,1]),
                  decreasing = TRUE,
                  index.return = TRUE)$ix

    inputs <- rownames(var.imp)[index]
    scores <- var.imp[index,1]
    remove.index <- which(scores >= 0.9*max(scores))
    print(scores)
    rnames <- inputs[remove.index]
    print('removing:')
    print(rnames)


    par.set1<-par.set0
    pnames<-names(par.set$pars)
    print(par.set1)
    for (index in c(1:k)){
      p = pnames[index]
      type = par.set$pars[[index]]$type
      if(max(scores)>0){
        if (p %in% rnames){
          val  = subset(bestDF, select = p)
          cval = as.vector(unlist(val))
          print(p)
          print(cval)
          trafo <- par.set1$pars[[index]]$trafo
          if (type == "logical1"){
            par.set1$pars[[index]]<-makeLogicalParam(p, default = cval, tunable = FALSE,  trafo = trafo)
          } else if(type == "discrete") {
            par.set1$pars[[index]]<-makeDiscreteParam(p, values=c(cval),  trafo = trafo)
          } else {
            delta <- max(1, round(cval * 10/100))
            ll <- max(cval - delta, par.set$pars[[index]]$lower)
            uu <- min(cval + delta, par.set$pars[[index]]$upper)
            if(type == "integer") {
              if (par.set$pars[[index]]$lower == 0 | par.set$pars[[index]]$upper == 1){
                par.set1$pars[[index]]<-makeIntegerParam(p, lower=cval, upper=cval, trafo = trafo)
              } else {
                par.set1$pars[[index]]<-makeIntegerParam(p, lower=ll, upper=uu, trafo = trafo)
              }
            } else {
              par.set1$pars[[index]]<-makeNumericParam(p, lower=ll, upper=uu, trafo = trafo)
            }
          }
        }
      }
    }
    print('problem:')
    print(par.set1)

    #redefine objecitive function with par.set1
    obj.fun = makeSingleObjectiveFunction(
    name = "hyperparameter search",
    fn = simple.obj.fun,
    par.set = par.set1
    )

    #ctrl = setMBOControlTermination(ctrl, max.evals = propose.points)
    design = generateDesign(n = propose.points, par.set = par.set1)

    temp<-rbind(design,reqDF[,-1])
    design <- head(temp, n = propose.points)


    USE_MODEL <- TRUE
    if(USE_MODEL){
      yvals <- predict(train.model,design)
      design <- cbind(y=yvals, design)
      ctrl = setMBOControlTermination(ctrl, max.evals = 2*propose.points)
    } else {
      ctrl = setMBOControlTermination(ctrl, max.evals = propose.points)
    }
    print("mbo-itr")
    print(yvals)

    print(summary(yvals))
    res = mbo(obj.fun, design = design, learner = surr.rf, control = ctrl, show.info = FALSE)
    itr_res<-as.data.frame(res$opt.path)
    itr_res<-cbind(itr_res, stime = as.numeric(time[3]))
    itr_res<-tail(itr_res, n = propose.points)

    par.set0<-par.set1
    itr <- itr + 1
    print("bug msg:")
    print(names(all_res))
    print(names(itr_res))
    all_res <- rbind(all_res, itr_res)
  }

  return(all_res)
}

  # Ask for parameters from Swift over queue
  OUT_put("Params")

  # Receive parameters message from Swift over queue
  # This is a string of R code containing arguments to main_function(),
  # e.g., "max.budget = 110, max.iterations = 10, design.size = 10, ..."
  msg <- IN_get()
  print(paste("Received params1 msg: ", msg))

  # Edit the R code to make a list constructor expression
  code = paste0("list(",msg,")")

  # Parse the R code, obtaining a list of unevaluated expressions
  # which are parameter=value , ...
  expressions <- eval(parse(text=code))

  # Process the param set file and remove it from the list of expressions:
  #  it is not an argument to the objective function
  source(expressions$param.set.file)
  expressions$param.set.file <- NULL

  # dummy objective function, only par.set is used
  # and param.set is sourced from param.set.file
  obj.fun = makeSingleObjectiveFunction(
    name = "hyperparameter search",
    fn = simple.obj.fun,
    par.set = param.set
  )

  final_res <- do.call(main_function, expressions)
  OUT_put("DONE")

  turbine_output <- Sys.getenv("TURBINE_OUTPUT")
  if (turbine_output != "") {
    setwd(turbine_output)
  }
  # This will be saved to experiment directory
  saveRDS(final_res,file = "final_res.Rds")

  setwd(wd)
  OUT_put("Look at final_res.Rds for final results.")
  print("algorithm done.")
