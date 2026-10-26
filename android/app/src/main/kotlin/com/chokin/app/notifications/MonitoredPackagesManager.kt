package com.chokin.app.notifications

import android.content.Context
import android.content.SharedPreferences

class MonitoredPackagesManager(context: Context) {
    private val prefs: SharedPreferences = context.getSharedPreferences("chokin_monitored_apps", Context.MODE_PRIVATE)

    companion object {
        private const val KEY_PACKAGES = "monitored_packages"
        val DEFAULT_PACKAGES = setOf(
            "com.nu.production",
            "com.samsung.android.spay",
            "com.samsung.android.raja.spay",
            "br.com.bb.android",
            "com.itau",
            "com.itau.personnalite",
            "com.itau.iti",
            "com.santander.app",
            "br.com.santander.way",
            "br.com.intermedium",
            "com.c6bank.app",
            "com.mercadopago.wallet",
            "com.mercadolibre",
            "com.picpay",
            "com.bradesco",
            "com.bradesco.cartoes",
            "br.gov.caixa.tem",
            "br.com.gruposbf.caixa"
        )
    }

    fun getMonitoredPackages(): Set<String> {
        val saved = prefs.getStringSet(KEY_PACKAGES, null)
        return if (saved != null) {
            saved + DEFAULT_PACKAGES
        } else {
            DEFAULT_PACKAGES
        }
    }

    fun updateMonitoredPackages(packages: Set<String>) {
        prefs.edit().putStringSet(KEY_PACKAGES, packages).apply()
    }

    fun isPackageMonitored(packageName: String): Boolean {
        val monitored = getMonitoredPackages()
        val pkg = packageName.lowercase()
        if (pkg.contains("walletnfcrel") || pkg.startsWith("com.google.android.gms")) return false
        return monitored.contains(packageName) ||
               monitored.any { pkg.startsWith(it.lowercase()) } ||
               pkg.contains("nubank") ||
               pkg.contains("mercadopago") ||
               pkg.contains("intermedium") ||
               pkg.contains("c6bank") ||
               pkg.contains("spay") ||
               pkg.contains("picpay") ||
               pkg.contains("santander") ||
               pkg.contains("itau") ||
               pkg.contains("bradesco") ||
               pkg == "android" ||
               pkg.contains("shell") ||
               pkg.contains("notification") ||
               pkg.contains("simulator") ||
               pkg.contains("creator")
    }
}
