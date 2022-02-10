from __future__ import division
cimport numpy as np
import numpy as np
from libc.math cimport log, sqrt, M_PI, exp, HUGE_VAL, atan2, acos, sin, cos
cimport cython
from numpy.linalg import det, inv
from scipy.stats import multivariate_normal as mn
from scipy.stats import invgamma
from scipy.special import gammaln

cdef double LOGSQRT2 = log(sqrt(2*M_PI))

cdef inline double log_add(double x, double y) nogil: return x+log(1.0+exp(y-x)) if x >= y else y+log(1.0+exp(x-y))
cdef inline double _scalar_log_norm(double x, double x0, double s): return -(x-x0)*(x-x0)/(2*s*s) - LOGSQRT2 - 0.5*log(s)

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef double _triple_product(np.ndarray[double, ndim = 1, mode = "c"] x, np.ndarray[double, ndim = 1, mode = "c"] mu, np.ndarray[double, ndim = 2, mode = "c"] inv_cov):
    cdef unsigned int i,j
    cdef unsigned int n = x.shape[0]
    cdef double res     = 0.0
    for i in range(n):
        for j in range(n):
            res += inv_cov[i,j]*(x[i]-mu[i])*(x[j]-mu[j])
    return res

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef double _log_norm(np.ndarray[double, ndim = 1, mode = "c"] x, np.ndarray[double, ndim = 1, mode = "c"] mu, np.ndarray[double, ndim = 2, mode = "c"] cov):
    cdef np.ndarray inv_cov  = np.linalg.inv(cov)
    cdef double exponent     = -0.5*_triple_product(x, mu, inv_cov)
    cdef double lognorm      = LOGSQRT2-0.5*np.linalg.slogdet(inv_cov)[1]
    return -lognorm+exponent

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef double _log_norm_with_inv(np.ndarray[double, ndim = 1, mode = "c"] x, np.ndarray[double, ndim = 1, mode = "c"] mu, np.ndarray[double, ndim = 2, mode = "c"] inv_cov):
    cdef double exponent     = -0.5*_triple_product(x, mu, inv_cov)
    cdef double lognorm      = LOGSQRT2-0.5*np.linalg.slogdet(inv_cov)[1]
    return -lognorm+exponent
             
def log_norm(np.ndarray[double, ndim = 1, mode = "c"] x, np.ndarray[double, ndim = 1, mode = "c"] x0, np.ndarray[double, ndim = 2, mode = "c"] sigma):
    return _log_norm(x, x0, sigma)

def mult_norm(np.ndarray[double, ndim = 1, mode = "c"] x, np.ndarray[double, ndim = 1, mode = "c"] x0, np.ndarray[double, ndim = 2, mode = "c"] inv_sigma):
    return np.exp(_log_norm_with_inv(x, x0, inv_sigma))

def scalar_log_norm(double x, double x0, double s):
    return _scalar_log_norm(x,x0,s)

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef double _log_prob_component(np.ndarray[double, ndim = 1, mode = "c"] mu, np.ndarray[double, ndim = 1, mode = "c"] mean, np.ndarray[double, ndim = 2, mode = "c"] sigma, double w):
    return log(w) + _log_norm(mu, mean, sigma)

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef double _log_prob_mixture(np.ndarray[double, ndim = 1, mode = "c"] mu, np.ndarray[double, ndim = 2, mode = "c"] sigma, object ev):
    cdef double logP = -HUGE_VAL
    for comp_mean, comp_cov, comp_weight in zip(ev.means, ev.covs, ev.w):
        logP = log_add(logP, _log_prob_component(mu, comp_mean, sigma + comp_cov, comp_weight))
    return logP

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef double _integrand(np.ndarray[double, ndim = 1, mode = "c"] mean, np.ndarray[double, ndim = 2, mode = "c"] covariance, list events, unsigned int dim):
    cdef unsigned int i,j
    cdef double logprob = 0.0
    cdef object ev
    for ev in events:
        logprob += _log_prob_mixture(mean, covariance, ev)
    return logprob

def integrand(np.ndarray[double, ndim = 1, mode = "c"] mean, np.ndarray[double, ndim = 2, mode = "c"] covariance, list events, unsigned int dim):
    return _integrand(mean, covariance, events, dim)

######
# 1D #
######

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef double _log_prob_component_1d(double mu, double mean, double sigma, double w):
    return log(w) + _scalar_log_norm(mu, mean, sigma)

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef double _log_prob_mixture_1d(double mu, double var, object ev):
    cdef double logP = -HUGE_VAL
    for comp_mean, comp_cov, comp_weight in zip(ev.means, ev.covs, ev.w):
        logP = log_add(logP, _log_prob_component_1d(mu, comp_mean[0], np.sqrt(var**2 + comp_cov[0,0]), comp_weight))
    return logP

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef double _integrand_1d(double mean, double var, list events, double a, double b):
    cdef unsigned int i,j
    cdef double logprob = 0.0
    cdef object ev
    for ev in events:
        logprob += _log_prob_mixture_1d(mean, var, ev)
    return logprob + _log_invgamma(var, a, b**2) - np.log(40) #FIXME: finire inv gamma
    
def integrand_1d(double var, double mean, list events, double a, double b):
    return np.exp(_integrand_1d(mean, var, events, a, b))

def log_integrand_1d(double mean, double var, list events, double a, double b):
    return _integrand_1d(mean, var, events, a, b)

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef double _log_invgamma(double var, double a, double b):
    return a*np.log(b) - (a+1)*np.log(var**2) - b/var**2 - gammaln(a)
