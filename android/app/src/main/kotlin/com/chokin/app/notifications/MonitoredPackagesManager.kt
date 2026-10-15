package com.chokin.app.notifications

import android.content.Context
import android.content.SharedPreferences

class MonitoredPackagesManager(context: Context) {
    private val prefs: SharedPreferences = context.getSharedPreferences("chokin_monitored_apps", Context.MODE_PRIVATE)

    companion object {
        private const val KEY_PACKAGES = "monitored_packages"
        val DEFAULT_PACKAGES = setOf(
            "com.nu.production",                     // Nubank
            "com.google.android.apps.walletnfcrel",  // Google Wallet
            "com.google.android.gms",                // Google Play Services / Google Pay
            "com.samsung.android.spay",              // Samsung Pay
            "com.samsung.android.raja.spay",         // Samsung Wallet
            "br.com.bb.android",                     // Banco do Brasil
            "com.itau",                              // Itaú
            "com.itau.personnalite",                 // Itaú Personnalité
            "com.itau.iti",                          // Iti Itaú
            "com.santander.app",                     // Santander
            "br.com.santander.way",                  // Santander Way
            "br.com.intermedium",                    // Banco Inter
            "com.c6bank.app",                        // C6 Bank
            "com.mercadopago.wallet",                // Mercado Pago
            "com.mercadolibre",                      // Mercado Livre
            "com.picpay",                            // PicPay
            "com.bradesco",                          // Bradesco
            "com.bradesco.cartoes",                  // Bradesco Cartões
            "br.gov.caixa.tem",                      // Caixa Tem
            "br.com.gruposbf.caixa"                  // Caixa
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
               pkg.contains("wallet") ||
               pkg.contains("google.android.gms") ||
               pkg.contains("walletnfcrel") ||
               pkg == "android" ||
               pkg.contains("shell") ||
               pkg.contains("notification") ||
               pkg.contains("simulator") ||
               pkg.contains("creator")
    }
}
