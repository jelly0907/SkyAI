package com.skyai.app.data.api

import android.util.Log
import com.google.gson.Gson
import com.google.gson.GsonBuilder
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object RetrofitClient {

    // ── Dev backend host ─────────────────────────────────────────────────
    //
    // Pick whichever line matches where you're running the app:
    //
    //   • Physical Android device on the same Wi-Fi as your Mac:
    //         "http://<your-mac>.local:8000/"
    //     where <your-mac> is the output of `scutil --get LocalHostName`
    //     on the Mac. mDNS resolves this to the Mac's current LAN IP
    //     automatically, so DHCP changes don't break it.
    //
    //   • Android Studio emulator:
    //         "http://10.0.2.2:8000/"
    //     10.0.2.2 is the emulator's special alias for the host machine's
    //     loopback. Doesn't work from a real device on Wi-Fi.
    //
    //   • Last-resort fallback (LAN IP literal):
    //         "http://192.168.x.y:8000/"
    //     `ipconfig getifaddr en0` on the Mac gives you the value. Works
    //     anywhere `.local` doesn't resolve, but you'll have to update it
    //     whenever DHCP rolls.
    //
    // Cleartext HTTP requires `android:usesCleartextTraffic="true"` on the
    // <application> tag in AndroidManifest.xml — already set.
    //
    // TODO before first device build: paste the output of
    //     scutil --get LocalHostName
    // (run on your Mac) into the BASE_URL host below.
    // Emulator: 10.0.2.2 is the AVD's alias for the host Mac's 127.0.0.1.
    // Physical device on Wi-Fi: swap to "http://Stones-MacBook-Air.local:8000/".
    private const val BASE_URL = "http://10.0.2.2:8000/"

    @Singleton
    @Provides
    fun provideGson(): Gson {
        return GsonBuilder()
            .setLenient()
            .create()
    }

    @Singleton
    @Provides
    fun provideOkHttpClient(): OkHttpClient {
        val loggingInterceptor = HttpLoggingInterceptor { message ->
            Log.d("OkHttp", message)
        }.apply {
            level = HttpLoggingInterceptor.Level.BODY
        }

        return OkHttpClient.Builder()
            .addInterceptor(loggingInterceptor)
            .connectTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
            .readTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
            .writeTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
            .build()
    }

    @Singleton
    @Provides
    fun provideRetrofit(
        okHttpClient: OkHttpClient,
        gson: Gson
    ): Retrofit {
        return Retrofit.Builder()
            .baseUrl(BASE_URL)
            .client(okHttpClient)
            .addConverterFactory(GsonConverterFactory.create(gson))
            .build()
    }

    @Singleton
    @Provides
    fun provideSkyAIApiService(retrofit: Retrofit): SkyAIApiService {
        return retrofit.create(SkyAIApiService::class.java)
    }
}
