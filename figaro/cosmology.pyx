from __future__ import division
import numpy as np
cimport numpy as np
from libc.math cimport log,exp,sqrt,cos,fabs,sin,sinh
cimport cython

cdef class CosmologicalParameters:

    def __cinit__(self, double h, double om, double ol, double w0, double w1):
        self.h = h
        self.om = om
        self.ol = ol
        self.w0 = w0
        self.w1 = w1
        self._LALCosmologicalParameters = XLALCreateCosmologicalParameters(self.h,self.om,self.ol,self.w0,self.w1,0.0)
    def __reduce__(self):
        return (CosmologicalParameters, (self.h, self.om, self.ol, self.w0, self.w1))

    cdef double _HubbleParameter(self, double z) nogil:
        return XLALHubbleParameter(z, self._LALCosmologicalParameters)

    cdef double _LuminosityDistance_double(self, double z) nogil:
        return XLALLuminosityDistance(self._LALCosmologicalParameters,z)

    cdef np.ndarray[double, ndim=1, mode="c"] _LuminosityDistance(self, np.ndarray[double, ndim=1, mode="c"] z):
        
        cdef unsigned int i, n = z.shape[0]
        cdef np.ndarray[double, ndim=1, mode="c"] DL = np.zeros(n)
        cdef double[:] DL_view = DL
        
        for i in range(n):
            DL_view[i] = self._LuminosityDistance_double(z[i])
        
        return DL
        

    cdef double _HubbleDistance(self) nogil:
        return XLALHubbleDistance(self._LALCosmologicalParameters)

    cdef double _IntegrateComovingVolumeDensity(self, double zmax) nogil:
        return XLALIntegrateComovingVolumeDensity(self._LALCosmologicalParameters,zmax)

    cdef double _IntegrateComovingVolume(self, double zmax) nogil:
        return XLALIntegrateComovingVolume(self._LALCosmologicalParameters,zmax)

    cdef double _UniformComovingVolumeDensity(self, double z) nogil:
        return XLALUniformComovingVolumeDensity(z, self._LALCosmologicalParameters)

    cdef double _UniformComovingVolumeDistribution(self, double z, double zmax) nogil:
        return XLALUniformComovingVolumeDistribution(self._LALCosmologicalParameters, z, zmax)

    cdef double _ComovingVolumeElement(self,double z) nogil:
        return XLALComovingVolumeElement(z, self._LALCosmologicalParameters)

    cdef double _ComovingVolume(self,double z) nogil:
        return XLALComovingVolume(self._LALCosmologicalParameters, z)

    cdef void _DestroyCosmologicalParameters(self) nogil:
        XLALDestroyCosmologicalParameters(self._LALCosmologicalParameters)
        return

    def HubbleParameter(self, double z):
        return self._HubbleParameter(z)

    def LuminosityDistance_double(self, double z):
        return self._LuminosityDistance_double(z)
    
    def LuminosityDistance(self, np.ndarray[double, ndim=1, mode="c"] z):
        return self._LuminosityDistance(z)

    def HubbleDistance(self):
        return self._HubbleDistance()

    def IntegrateComovingVolumeDensity(self, double zmax):
        return self._IntegrateComovingVolumeDensity(zmax)

    def IntegrateComovingVolume(self, double zmax):
        return self._IntegrateComovingVolume(zmax)

    def UniformComovingVolumeDensity(self, double z):
        return self._UniformComovingVolumeDensity(z)

    def UniformComovingVolumeDistribution(self, double z, double zmax):
        return self._UniformComovingVolumeDistribution(z, zmax)

    def ComovingVolumeElement(self, double z):
        return self._ComovingVolumeElement(z)

    def ComovingVolume(self, double z):
        return self._ComovingVolume(z)

    def DestroyCosmologicalParameters(self):
        self._DestroyCosmologicalParameters()
        return

cdef class CosmologicalRateParameters:

    def __cinit__(self, double r0, double W, double R, double Q):
        self.r0 = r0
        self.W = W
        self.R = R
        self.Q = Q
        
    cpdef double StarFormationDensity(self, double z):
        return self.r0*(1.0+self.W)*exp(self.Q*z)/(exp(self.R*z)+self.W)

def StarFormationDensity(const double z, const double r0, const double W, const double R, const double Q):
    return _StarFormationDensity(z, r0, W, R, Q)

cdef double _StarFormationDensity(const double z,
                                  const double r0,
                                  const double W,
                                  const double R,
                                  const double Q) nogil:
    return r0*(1.0+W)*exp(Q*z)/(exp(R*z)+W)

def IntegrateRateWeightedComovingVolumeDensity(const double r0,
                                               const double W,
                                               const double R,
                                               const double Q,
                                               CosmologicalParameters omega,
                                               const double zmin = 0.0,
                                               const double zmax = 1.0):
    return _IntegrateRateWeightedComovingVolumeDensity(r0, W, R, Q, omega, zmin, zmax)

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef double _IntegrateRateWeightedComovingVolumeDensity(const double r0,
                                                        const double W,
                                                        const double R,
                                                        const double Q,
                                                        CosmologicalParameters omega,
                                                        const double zmin,
                                                        const double zmax) nogil:
    cdef int i = 0
    cdef int N = 32
    cdef double I = 0
    cdef double dz = (zmax-zmin)/N
    cdef double z  = zmin
    for i in range(N):
        I += _StarFormationDensity(z, r0, W, R, Q)*omega._UniformComovingVolumeDensity(z)
        z += dz
    return I*dz
