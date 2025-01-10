package com.mrousavy.camera.core

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.util.Log
import androidx.core.content.ContextCompat

class MetadataProvider(val context: Context) : LocationListener {
  private val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
  companion object {
    private const val TAG = "MetadataProvider"
    private const val UPDATE_INTERVAL_MS = 5000L
    private const val UPDATE_DISTANCE_M = 5f
  }

  private val hasLocationPermission: Boolean
    get() {
      val fineLocationStatus = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION)
      val coarseLocationStatus = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION)
      return fineLocationStatus == PackageManager.PERMISSION_GRANTED || coarseLocationStatus == PackageManager.PERMISSION_GRANTED
    }
  var location: Location? = null
    private set

  @SuppressLint("MissingPermission")
  fun enableLocationUpdates(enable: Boolean) {
    if (enable) {
      if (!hasLocationPermission) {
        throw LocationPermissionError()
      }

      Log.i(TAG, "Start updating location...")
      locationManager.requestLocationUpdates(LocationManager.GPS_PROVIDER, UPDATE_INTERVAL_MS, UPDATE_DISTANCE_M, this)
      this.location = locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER)

      if (this.location == null){
        // Request the current location if lastKnownLocation is null
        locationManager.requestSingleUpdate(LocationManager.GPS_PROVIDER, this, null)
      }
    } else {
      Log.i(TAG, "Stopping location updates...")
      locationManager.removeUpdates(this)
    }
  }

  override fun onLocationChanged(location: Location) {
    Log.i(TAG, "Location updated: ${location.latitude}, ${location.longitude}")
    this.location = location
  }

  override fun onProviderDisabled(provider: String) {
    Log.i(TAG, "Location Provider $provider has been disabled.")
  }

  override fun onProviderEnabled(provider: String) {
    Log.i(TAG, "Location Provider $provider has been enabled.")
  }

  @Deprecated("Deprecated in Java", ReplaceWith("", ""))
  override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {
    Log.i(TAG, "Location Provider $provider status changed: $status")
  }
}
