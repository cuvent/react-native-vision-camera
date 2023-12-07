package com.mrousavy.camera.example

import android.app.Application
import com.facebook.react.PackageList
import com.facebook.react.ReactApplication
import com.facebook.react.ReactHost
import com.facebook.react.ReactNativeHost
import com.facebook.react.ReactPackage
import com.facebook.react.defaults.DefaultNewArchitectureEntryPoint.load
import com.facebook.react.defaults.DefaultReactHost.getDefaultReactHost
import com.facebook.react.defaults.DefaultReactNativeHost
import com.facebook.soloader.SoLoader
import com.mrousavy.camera.CameraPackage
import com.mrousavy.camera.frameprocessor.FrameProcessorPluginRegistry

class MainApplication : Application(), ReactApplication {
  companion object {
    init {
      // Register the Frame Processor Plugins for our app
      FrameProcessorPluginRegistry.addFrameProcessorPlugin("example_plugin") { options ->
        ExampleFrameProcessorPlugin(options)
      }
      FrameProcessorPluginRegistry.addFrameProcessorPlugin("example_kotlin_swift_plugin") { options ->
        ExampleKotlinFrameProcessorPlugin(options)
      }
    }
  }

  override val reactNativeHost: ReactNativeHost =
      object : DefaultReactNativeHost(this) {
        override fun getPackages(): List<ReactPackage> {
          // Packages that cannot be autolinked yet can be added manually here, for example:
          val packages = PackageList(this).packages
          packages.add(CameraPackage())
          return packages
        }

        override fun getJSMainModuleName(): String = "index"

        override fun getUseDeveloperSupport(): Boolean = BuildConfig.DEBUG

        override val isNewArchEnabled: Boolean = BuildConfig.IS_NEW_ARCHITECTURE_ENABLED
        override val isHermesEnabled: Boolean = BuildConfig.IS_HERMES_ENABLED
      }

  override val reactHost: ReactHost
    get() = getDefaultReactHost(this.applicationContext, reactNativeHost)

  override fun onCreate() {
    super.onCreate()
    SoLoader.init(this, false)
    if (BuildConfig.IS_NEW_ARCHITECTURE_ENABLED) {
      // If you opted-in for the New Architecture, we load the native entry point for this app.
      load()
    }
  }
}
