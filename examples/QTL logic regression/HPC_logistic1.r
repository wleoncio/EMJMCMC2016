# ssh -X -Y -l aliaksah abel.uio.no
# scp -r  /usit/abel/u1/aliaksah/simulations/scenario1  aliaksah@pittheus.uio.no://mn/sarpanitu/ansatte-u2/aliaksah/Desktop/package/simulations


source("https://raw.githubusercontent.com/aliaksah/EMJMCMC2016/master/R/the_mode_jumping_package2.r")

library(inline)
includes <- '#include <sys/wait.h>'
code <- 'int wstat; while (waitpid(-1, &wstat, WNOHANG) > 0) {};'
wait <- cfunction(body=code, includes=includes, convention='.C')


estimate.logic.glm <- function(formula, data, family, n, m, r = 1)
{
  X <- model.matrix(object = formula,data = data)
  out <- bayesglm.fit(x = X, y = data[,51], family=family,coefprior=aic.prior())
  p <- out$rank
  fmla.proc<-as.character(formula)[2:3]
  fobserved <- fmla.proc[1]
  fmla.proc[2]<-stri_replace_all(str = fmla.proc[2],fixed = " ",replacement = "")
  fmla.proc[2]<-stri_replace_all(str = fmla.proc[2],fixed = "\n",replacement = "")
  fparam <-stri_split_fixed(str = fmla.proc[2],pattern = "+",omit_empty = F)[[1]]
  sj<-(stri_count_fixed(str = fparam, pattern = "&"))
  sj<-sj+(stri_count_fixed(str = fparam, pattern = "|"))
  Jprior <- prod(factorial(sj)/((m^sj)*2^(3*sj-2)))
  #tn<-sum(stri_count_fixed(str = fmla.proc[2], pattern = "I("))
  mlik = (-(out$deviance + log(n)*(out$rank - log(2*pi))) + 2*log(Jprior) + p*log(r))/2
  if(mlik==-Inf)
    mlik = -10000
  return(list(mlik = mlik,waic = -(out$deviance + 2*out$rank) , dic =  -(out$deviance + log(n)*out$rank),summary.fixed =list(mean = coefficients(out))))
}


parall.gmj <<- mclapply


simplifyposteriors<-function(X,posteriors,th=0.0001,thf=0.5)
{
  posteriors<-posteriors[-which(posteriors[,2]<th),]
  rhash<-hash()
  for(i in 1:length(posteriors[,1]))
  {
    expr<-posteriors[i,1]
    print(expr)
    res<-model.matrix(data=X,object = as.formula(paste0("Y1~",expr)))
    res[,1]<-res[,1]-res[,2]
    ress<-c(stri_flatten(res[,1],collapse = ""),stri_flatten(res[,2],collapse = ""),posteriors[i,2],expr)
    if(!(ress[1] %in% values(rhash)||(ress[2] %in% values(rhash))))
      rhash[[ress[1]]]<-ress
    else
    {
      if(ress[1] %in% keys(rhash))
      {
        rhash[[ress[1]]][3]<- (as.numeric(rhash[[ress[1]]][3]) + as.numeric(ress[3]))
        if(stri_length(rhash[[ress[1]]][4])>stri_length(expr))
          rhash[[ress[1]]][4]<-expr
      }
      else
      {
        rhash[[ress[2]]][3]<- (as.numeric(rhash[[ress[2]]][3]) + as.numeric(ress[3]))
        if(stri_length(rhash[[ress[2]]][4])>stri_length(expr))
          rhash[[ress[2]]][4]<-expr
      }
    }

  }
  res<-as.data.frame(t(values(rhash)[c(3,4),]))
  res$V1<-as.numeric(as.character(res$V1))
  res<-res[which(res$V1>thf),]
  res<-res[order(res$V1, decreasing = T),]
  clear(rhash)
  rm(rhash)
  res[which(res[,1]>1),1]<-1
  colnames(res)<-c("posterior","tree")
  return(res)
}


MM = 100
M = 32
NM= 1000
compmax = 16
th<-(10)^(-5)
thf<-0.05

paral<-function(X,FUN)
{
  return(mclapply(X = X,FUN = FUN,mc.preschedule = T, mc.cores = 32))
}

runpar<-function(vect)
{

  tryCatch({
    set.seed(as.integer(vect[24]))
    do.call(runemjmcmc, vect[1:23])
    vals<-values(hashStat)
    fparam<-mySearch$fparam
    cterm<-max(vals[1,],na.rm = T)
    ppp<-mySearch$post_proceed_results_hash(hashStat = hashStat)
    post.populi<-sum(exp(values(hashStat)[1,][1:NM]-cterm),na.rm = T)
    clear(hashStat)
    rm(hashStat)
    rm(vals)
  },error = function(err){
    print(paste0("error in thread",vect[24]))
    vect[24]<-vect[24]+as.integer(runif(1,1,10000))
    return(runpar(vect))
  },finally = {

    return(list(post.populi = post.populi, p.post =  ppp$p.post, cterm = cterm, fparam = fparam))

  })
}

#print("wait 2 hours")
#Sys.sleep(7200)

for(j in 1:MM)
{

  resa<-array(data = 0,dim = c(16,M*3))
  post.popul <- array(0,M)
  max.popul <- array(0,M)
  set.seed(j)
  X1<- as.data.frame(array(data = rbinom(n = 50*1000,size = 1,prob = 0.3),dim = c(1000,50)))
  Y1=-0.7+1*(X1$V1*(1-X1$V4)) + 1*(X1$V8*X1$V11)+1*(X1$V5*X1$V9)
  X1$Y1<-round(1.0/(1.0+exp(-Y1)))

  mean(X1$Y1)

  formula1 = as.formula(paste(colnames(X1)[51],"~ 1 +",paste0(colnames(X1)[-c(51)],collapse = "+")))
  data.example = as.data.frame(X1)

  vect<-list(formula = formula1,data = X1,presearch = T,locstop = F ,estimator = estimate.logic.glm,estimator.args =  list(data = data.example,family = binomial(),n = 1000, m = 50),recalc_margin = 250, save.beta = F,interact = T,relations = c("","lgx2","cos","sigmoid","tanh","atan","erf"),relations.prob =c(0.4,0.0,0.0,0.0,0.0,0.0,0.0),interact.param=list(allow_offsprings=1,mutation_rate = 300,last.mutation = 5000, max.tree.size = 4, Nvars.max = (compmax-1),p.allow.replace=0.9,p.allow.tree=0.2,p.nor=0,p.and = 0.9),n.models = 10000,unique = T,max.cpu = 4,max.cpu.glob = 4,create.table = F,create.hash = T,pseudo.paral = T,burn.in = 50,outgraphs=F,print.freq = 1000,advanced.param = list(
    max.N.glob=as.integer(10),
    min.N.glob=as.integer(5),
    max.N=as.integer(3),
    min.N=as.integer(1),
    printable = F))

  params <- list(vect)[rep(1,32)]

  for(i in 1:M)
  {
    params[[i]]$cpu<-i
    params[[i]]$simul<-"scenario_log_1_"
    params[[i]]$simid<-j
  }
  gc()
  print(paste0("begin simulation ",j))
  results<-parall.gmj(X = params,FUN = runpar,mc.preschedule = F, mc.cores = 32)
  wait()

  #print(results)

  resa<-array(data = 0,dim = c(compmax,M*3))
  post.popul <- array(0,M)
  max.popul <- array(0,M)
  for(k in 1:M)
  {
    max.popul[k]<-results[[k]]$cterm
    post.popul[k]<-results[[k]]$post.populi
    resa[,k*3-2]<-c(results[[k]]$fparam,"Post.Gen.Max")
    resa[,k*3-1]<-c(results[[k]]$p.post,results[[k]]$cterm)
    resa[,k*3]<-rep(post.popul[k],length(results[[k]]$p.post)+1)
  }
  gc()
  rm(results)
  ml.max<-max(max.popul)
  post.popul<-post.popul*exp(-ml.max+max.popul)
  p.gen.post<-post.popul/sum(post.popul)
  hfinal<-hash()
  for(ii in 1:M)
  {
    resa[,ii*3]<-p.gen.post[ii]*as.numeric(resa[,ii*3-1])
    resa[length(resa[,ii*3]),ii*3]<-p.gen.post[ii]
    if(p.gen.post[ii]>0)
    {
      for(jj in 1:(length(resa[,ii*3])-1))
      {
        if(resa[jj,ii*3]>0)
        {
          #print(paste0(ii,"  and ",jj))
          if(as.integer(has.key(hash = hfinal,key =resa[jj,ii*3-2]))==0)
            hfinal[[resa[jj,ii*3-2]]]<-as.numeric(resa[jj,ii*3])
          else
            hfinal[[resa[jj,ii*3-2]]]<-hfinal[[resa[jj,ii*3-2]]]+as.numeric(resa[jj,ii*3])
        }

      }
    }
  }

  posteriors<-values(hfinal)
  clear(hfinal)
  rm(hfinal)
  rm(resa)
  rm(post.popul)
  rm(max.popul)
  posteriors<-as.data.frame(posteriors)
  posteriors<-data.frame(X=row.names(posteriors),x=posteriors$posteriors)
  posteriors$X<-as.character(posteriors$X)
  tryCatch({
    res1<-simplifyposteriors(X = X1,posteriors = posteriors, th,thf)
    write.csv(x =res1,row.names = F,file = paste0("postLog1eta_",j,".csv"))},error = function(err){
      print("error")
      write.csv(x =posteriors,row.names = F,file = paste0("posteriorsLog1eta_",j,".csv"))},finally = {
        print(paste0("end simulation ",j))
      })
  rm(X1)
  rm(data.example)
  rm(vect)
  rm(params)
  gc()
  print(paste0("end simulation ",j))

}


