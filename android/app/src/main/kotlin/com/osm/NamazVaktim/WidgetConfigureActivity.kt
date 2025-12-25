package com.osm.NamazVaktim

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.text.Spannable
import android.text.SpannableString
import android.text.style.StyleSpan
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.*
import androidx.appcompat.app.AppCompatActivity
import androidx.core.graphics.ColorUtils
import com.google.android.material.slider.Slider
import kotlin.math.roundToInt

/**
 * Widget yapılandırma Activity'si (MVVM mimarisi - View katmanı)
 * Kullanıcı widget ayarlarını bu ekrandan yapılandırır.
 */
class WidgetConfigureActivity : AppCompatActivity() {
    
    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    private lateinit var viewModel: WidgetConfigureViewModel
    private lateinit var widgetType: WidgetConfigureViewModel.WidgetType
    
    // UI bileşenleri
    private lateinit var opacitySlider: Slider
    private lateinit var opacityValueText: TextView
    private lateinit var gradientModeDropdown: AutoCompleteTextView
    private lateinit var cardRadiusSlider: Slider
    private lateinit var cardRadiusValueText: TextView
    private lateinit var textColorModeDropdown: AutoCompleteTextView
    private lateinit var bgColorModeDropdown: AutoCompleteTextView
    private lateinit var saveButton: Button
    private lateinit var cancelButton: Button
    private lateinit var layoutBgColorMode: com.google.android.material.textfield.TextInputLayout
    
    // Calendar Specific UI
    private lateinit var layoutCalendarSettings: LinearLayout
    private lateinit var dropdownDateDisplayMode: AutoCompleteTextView
    private lateinit var dropdownHijriFontStyle: AutoCompleteTextView
    private lateinit var dropdownGregorianFontStyle: AutoCompleteTextView

    // TextOnly Specific UI
    private lateinit var textTextSizeTitle: TextView
    private lateinit var layoutTextSizeContainer: LinearLayout
    private lateinit var sliderTextSize: Slider
    private lateinit var textTextSizeValue: TextView
    
    // Önizleme bileşenleri
    private var previewView: View? = null
    private lateinit var previewContainer: FrameLayout
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Material You Dynamic Colors (Sistem renklerini kullan)
        try {
            com.google.android.material.color.DynamicColors.applyToActivityIfAvailable(this)
        } catch (e: Exception) {
            Log.e("WidgetConfigure", "DynamicColors hatası", e)
        }
        
        try {
            Log.d("WidgetConfigure", "onCreate başladı")
            
            // Widget ID'yi intent'ten al
            val intent = intent
            val extras = intent.extras
            if (extras != null) {
                appWidgetId = extras.getInt(
                    AppWidgetManager.EXTRA_APPWIDGET_ID,
                    AppWidgetManager.INVALID_APPWIDGET_ID
                )
                Log.d("WidgetConfigure", "Widget ID: $appWidgetId")
            } else {
                Log.w("WidgetConfigure", "Intent extras null!")
            }
            
            // Geçersiz widget ID kontrolü
            if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
                Log.e("WidgetConfigure", "Geçersiz widget ID, activity kapatılıyor")
                finish()
                return
            }
            
            // ViewModel'i başlat
            viewModel = WidgetConfigureViewModel()
            
            // Widget türünü belirle
            widgetType = viewModel.getWidgetType(this, appWidgetId)
            Log.d("WidgetConfigure", "Widget türü: $widgetType")
            
            // Layout'u ayarla
            setContentView(R.layout.activity_widget_configure)
            Log.d("WidgetConfigure", "Layout yüklendi")
            
            // UI bileşenlerini bağla
            initializeViews()
            Log.d("WidgetConfigure", "Views initialize edildi")
            
            // Mevcut ayarları yükle
            loadCurrentSettings()
            Log.d("WidgetConfigure", "Ayarlar yüklendi")
            
            // Event listener'ları ayarla
            setupListeners()
            Log.d("WidgetConfigure", "Listeners ayarlandı")
            
            // İlk önizleme güncellemesi
            updatePreview()
            
        } catch (e: Exception) {
            Log.e("WidgetConfigure", "onCreate hatası", e)
            e.printStackTrace()
            finish()
        }
    }
    
    private fun initializeViews() {
        opacitySlider = findViewById(R.id.slider_opacity)
        opacityValueText = findViewById(R.id.text_opacity_value)
        gradientModeDropdown = findViewById(R.id.dropdown_gradient_mode)
        cardRadiusSlider = findViewById(R.id.slider_card_radius)
        cardRadiusValueText = findViewById(R.id.text_card_radius_value)
        textColorModeDropdown = findViewById(R.id.dropdown_text_color_mode)
        bgColorModeDropdown = findViewById(R.id.dropdown_bg_color_mode)
        layoutBgColorMode = findViewById(R.id.layout_bg_color_mode)
        saveButton = findViewById(R.id.button_save)
        cancelButton = findViewById(R.id.button_cancel)
        previewContainer = findViewById(R.id.widget_preview_container)
        
        // Calendar Specific
        layoutCalendarSettings = findViewById(R.id.layout_calendar_settings)
        dropdownDateDisplayMode = findViewById(R.id.dropdown_date_display_mode)
        dropdownHijriFontStyle = findViewById(R.id.dropdown_hijri_font_style)
        dropdownGregorianFontStyle = findViewById(R.id.dropdown_gregorian_font_style)

        // TextOnly Specific
        textTextSizeTitle = findViewById(R.id.text_text_size_title)
        layoutTextSizeContainer = findViewById(R.id.layout_text_size_container)
        sliderTextSize = findViewById(R.id.slider_text_size)
        textTextSizeValue = findViewById(R.id.text_text_size_value)
        
        // Widget türüne göre başlık ayarla ve önizlemeyi yükle
        val titleText = findViewById<TextView>(R.id.text_title)
        
        val layoutId = when (widgetType) {
            WidgetConfigureViewModel.WidgetType.SMALL -> {
                titleText.text = getString(R.string.configure_small_widget)
                R.layout.widget_small
            }
            WidgetConfigureViewModel.WidgetType.TEXT_ONLY -> {
                titleText.text = getString(R.string.configure_text_widget)
                R.layout.widget_textonly
            }
            WidgetConfigureViewModel.WidgetType.CALENDAR -> {
                titleText.text = getString(R.string.configure_calendar_widget)
                R.layout.widget_calendar
            }
        }
        
        // Önizleme layoutunu inflate et
        previewView = layoutInflater.inflate(layoutId, previewContainer, false)
        previewContainer.addView(previewView)
        
        // Widget türüne göre ayar görünürlüğünü ayarla
        setupWidgetSpecificSettings()
        
        // Önizleme yüzeyini hazırla
        setupPreviewSurface()
    }
    
    private fun setupWidgetSpecificSettings() {
        // TextOnly widget için sadece metin rengi gösterilir
        // Diğer widget'lar için tüm ayarlar gösterilir
        
        try {
            // ID'lerle direkt erişim
            val opacityTitle = findViewById<TextView>(R.id.text_opacity_title)
            val opacityContainer = findViewById<View>(R.id.layout_opacity_container)
            val dividerOpacity = findViewById<View>(R.id.divider_opacity)
            
            val cardRadiusTitle = findViewById<TextView>(R.id.text_card_radius_title)
            val cardRadiusContainer = findViewById<View>(R.id.layout_card_radius_container)
            val dividerCardRadius = findViewById<View>(R.id.divider_card_radius)
            
            val gradientModeLayout = findViewById<com.google.android.material.textfield.TextInputLayout>(R.id.layout_gradient_mode)
            // layoutBgColorMode zaten yukarıda tanımlandı
            
            when (widgetType) {
                WidgetConfigureViewModel.WidgetType.TEXT_ONLY -> {
                    // TextOnly widget: Sadece metin rengi ve metin boyutu gösterilir
                    opacityTitle?.visibility = View.GONE
                    opacityContainer?.visibility = View.GONE
                    dividerOpacity?.visibility = View.GONE
                    
                    cardRadiusTitle?.visibility = View.GONE
                    cardRadiusContainer?.visibility = View.GONE
                    dividerCardRadius?.visibility = View.GONE
                    
                    gradientModeLayout?.visibility = View.GONE
                    layoutBgColorMode.visibility = View.GONE
                    
                    layoutCalendarSettings.visibility = View.GONE
                    
                    // Metin Boyutu GÖSTER
                    textTextSizeTitle.visibility = View.VISIBLE
                    layoutTextSizeContainer.visibility = View.VISIBLE
                    
                    Log.d("WidgetConfigure", "TextOnly widget ayarları düzenlendi")
                }
                WidgetConfigureViewModel.WidgetType.SMALL -> {
                    // Small widget: Tüm ayarlar gösterilir, Calendar ve TextSize hariç
                    opacityTitle?.visibility = View.VISIBLE
                    opacityContainer?.visibility = View.VISIBLE
                    dividerOpacity?.visibility = View.VISIBLE
                    
                    cardRadiusTitle?.visibility = View.VISIBLE
                    cardRadiusContainer?.visibility = View.VISIBLE
                    dividerCardRadius?.visibility = View.VISIBLE
                    
                    gradientModeLayout?.visibility = View.VISIBLE
                    layoutBgColorMode.visibility = View.VISIBLE
                    
                    layoutCalendarSettings.visibility = View.GONE
                    textTextSizeTitle.visibility = View.GONE
                    layoutTextSizeContainer.visibility = View.GONE
                }
                WidgetConfigureViewModel.WidgetType.CALENDAR -> {
                    // Calendar widget: Tüm ayarlar + Calendar özel ayarlar
                    opacityTitle?.visibility = View.VISIBLE
                    opacityContainer?.visibility = View.VISIBLE
                    dividerOpacity?.visibility = View.VISIBLE
                    
                    cardRadiusTitle?.visibility = View.VISIBLE
                    cardRadiusContainer?.visibility = View.VISIBLE
                    dividerCardRadius?.visibility = View.VISIBLE
                    
                    gradientModeLayout?.visibility = View.VISIBLE
                    layoutBgColorMode.visibility = View.VISIBLE
                    
                    layoutCalendarSettings.visibility = View.VISIBLE
                    textTextSizeTitle.visibility = View.GONE
                    layoutTextSizeContainer.visibility = View.GONE
                    
                    Log.d("WidgetConfigure", "Calendar widget tüm ayarları gösterildi")
                }
            }
        } catch (e: Exception) {
            Log.e("WidgetConfigure", "setupWidgetSpecificSettings hatası", e)
            e.printStackTrace()
            // Hata durumunda tüm ayarları göster (güvenli varsayılan)
        }
    }
    
    private fun setupPreviewSurface() {
        previewView?.let { view ->
            val dimensions = resolvePreviewDimensions()
            
            // Widget view'ın layout params'ını ayarla
            val params = FrameLayout.LayoutParams(
                dimensions.widthPx,
                dimensions.heightPx,
                Gravity.CENTER
            )
            view.layoutParams = params
            
            // Container'ın layout params'ını ayarla - wrap_content ve center gravity
            val containerParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER
            )
            previewContainer.layoutParams = containerParams
            
            // Ortak TextView'lar
            val tvTitle = view.findViewById<TextView>(R.id.tv_title)
            val tvSubtitle = view.findViewById<TextView>(R.id.tv_subtitle)
            
            // Widget tipine göre veri doldur
            when (widgetType) {
                WidgetConfigureViewModel.WidgetType.SMALL -> {
                    tvTitle?.text = "İkindi"
                    tvSubtitle?.text = "00:45"
                }
                WidgetConfigureViewModel.WidgetType.TEXT_ONLY -> {
                    tvTitle?.text = "Akşam"
                    tvSubtitle?.text = "02:15"
                }
                WidgetConfigureViewModel.WidgetType.CALENDAR -> {
                    val tvGregorian = view.findViewById<TextView>(R.id.tv_gregorian_date)
                    val tvHijri = view.findViewById<TextView>(R.id.tv_hijri_date)
                    tvGregorian?.text = "2 Aralık 2025"
                    tvHijri?.text = "10 Cemaziyelahir 1447"
                    // Visibility updatePreview'da yönetilecek
                }
            }
        }
    }
    
    private fun loadCurrentSettings() {
        val settings = viewModel.loadWidgetSettings(this, appWidgetId, widgetType)
        
        // Metin rengi modu ayarla (tüm widget türleri için)
        val textColorAdapter = ArrayAdapter.createFromResource(
            this,
            R.array.text_color_modes,
            android.R.layout.simple_dropdown_item_1line
        )
        textColorModeDropdown.setAdapter(textColorAdapter)
        val textColorIndex = settings.textColorMode.coerceIn(0, 2)
        textColorModeDropdown.setText(textColorAdapter.getItem(textColorIndex).toString(), false)
        
        // TextOnly Specific Loading
        if (widgetType == WidgetConfigureViewModel.WidgetType.TEXT_ONLY) {
            val textSizePct = settings.textSizePct.coerceIn(80, 140)
            sliderTextSize.value = textSizePct.toFloat()
            textTextSizeValue.text = "${textSizePct}%"
            
            // TextOnly için diğer ayarları yüklemeye gerek yok
            return
        }
        
        // Calendar Specific Loading
        if (widgetType == WidgetConfigureViewModel.WidgetType.CALENDAR) {
            val dateDisplayAdapter = ArrayAdapter.createFromResource(
                this,
                R.array.date_display_modes,
                android.R.layout.simple_dropdown_item_1line
            )
            dropdownDateDisplayMode.setAdapter(dateDisplayAdapter)
            val displayIndex = settings.dateDisplayMode.coerceIn(0, 2)
            dropdownDateDisplayMode.setText(dateDisplayAdapter.getItem(displayIndex).toString(), false)
            
            val fontStyleAdapter = ArrayAdapter.createFromResource(
                this,
                R.array.font_styles,
                android.R.layout.simple_dropdown_item_1line
            )
            dropdownHijriFontStyle.setAdapter(fontStyleAdapter)
            val hijriIndex = settings.hijriFontStyle.coerceIn(0, 1)
            dropdownHijriFontStyle.setText(fontStyleAdapter.getItem(hijriIndex).toString(), false)
            
            dropdownGregorianFontStyle.setAdapter(fontStyleAdapter)
            val gregorianIndex = settings.gregorianFontStyle.coerceIn(0, 1)
            dropdownGregorianFontStyle.setText(fontStyleAdapter.getItem(gregorianIndex).toString(), false)
        }
        
        // Small ve Calendar widget için genel ayarlar yüklenir
        // Opaklık ayarla (0-255 -> 0-100 yüzde)
        val opacityPercent = (settings.cardOpacity * 100 / 255).coerceIn(0, 100)
        opacitySlider.value = opacityPercent.toFloat()
        opacityValueText.text = "${opacityPercent}%"
        
        // Gradyan modu ayarla
        val gradientAdapter = ArrayAdapter.createFromResource(
            this,
            R.array.gradient_modes,
            android.R.layout.simple_dropdown_item_1line
        )
        gradientModeDropdown.setAdapter(gradientAdapter)
        val gradientIndex = settings.gradientMode.coerceIn(0, 2)
        gradientModeDropdown.setText(gradientAdapter.getItem(gradientIndex).toString(), false)
        
        // Arkaplan rengi görünürlüğünü güncelle
        layoutBgColorMode.visibility = if (gradientIndex == 2) View.GONE else View.VISIBLE
        
        // Köşe yarıçapı ayarla (0-120 dp)
        cardRadiusSlider.value = settings.cardRadius.coerceIn(0, 120).toFloat()
        cardRadiusValueText.text = "${settings.cardRadius}dp"
        
        // Arka plan rengi modu ayarla
        val bgColorAdapter = ArrayAdapter.createFromResource(
            this,
            R.array.bg_color_modes,
            android.R.layout.simple_dropdown_item_1line
        )
        bgColorModeDropdown.setAdapter(bgColorAdapter)
        val bgColorIndex = settings.bgColorMode.coerceIn(0, 2)
        bgColorModeDropdown.setText(bgColorAdapter.getItem(bgColorIndex).toString(), false)
    }
    
    private fun setupListeners() {
        // Opaklık slider
        opacitySlider.addOnChangeListener { _, value, _ ->
            opacityValueText.text = "${value.toInt()}%"
            updatePreview()
        }
        
        // Köşe yarıçapı slider
        cardRadiusSlider.addOnChangeListener { _, value, _ ->
            cardRadiusValueText.text = "${value.toInt()}dp"
            updatePreview()
        }
        
        // Dropdown listeners
        gradientModeDropdown.setOnItemClickListener { _, _, _, _ -> 
            val index = getDropdownIndex(gradientModeDropdown)
            // Renkli mod (2) seçildiyse arkaplan rengi seçeneğini gizle
            layoutBgColorMode.visibility = if (index == 2) View.GONE else View.VISIBLE
            updatePreview() 
        }
        textColorModeDropdown.setOnItemClickListener { _, _, _, _ -> updatePreview() }
        bgColorModeDropdown.setOnItemClickListener { _, _, _, _ -> updatePreview() }
        
        // Calendar specific listeners
        if (widgetType == WidgetConfigureViewModel.WidgetType.CALENDAR) {
            dropdownDateDisplayMode.setOnItemClickListener { _, _, _, _ -> updatePreview() }
            dropdownHijriFontStyle.setOnItemClickListener { _, _, _, _ -> updatePreview() }
            dropdownGregorianFontStyle.setOnItemClickListener { _, _, _, _ -> updatePreview() }
        }
        
        // TextOnly specific listeners
        if (widgetType == WidgetConfigureViewModel.WidgetType.TEXT_ONLY) {
            sliderTextSize.addOnChangeListener { _, value, _ ->
                textTextSizeValue.text = "${value.toInt()}%"
                updatePreview()
            }
        }
        
        // Kaydet butonu
        saveButton.setOnClickListener {
            saveConfiguration()
        }
        
        // İptal butonu
        cancelButton.setOnClickListener {
            finish()
        }
    }
    
    private fun updatePreview() {
        val view = previewView ?: return
        
        // TextOnly widget için sadece metin rengi ve boyutu güncellenir
        val textColorMode = getDropdownIndex(textColorModeDropdown)
        
        if (widgetType == WidgetConfigureViewModel.WidgetType.TEXT_ONLY) {
            // TextOnly widget: Sadece metin renklerini ve boyutunu güncelle
            val textSizePct = sliderTextSize.value.toInt()
            updateTextOnlyPreview(view, textColorMode, textSizePct)
            return
        }
        
        // Small ve Calendar widget için tüm ayarlar
        val opacityPercent = opacitySlider.value.toInt()
        val cardRadiusDp = cardRadiusSlider.value.toInt()
        val bgColorMode = getDropdownIndex(bgColorModeDropdown)
        val gradientMode = getDropdownIndex(gradientModeDropdown)
        val accentColor = resolveAccentColor()
        val secondaryColor = resolveSecondaryColor()
        val isDynamicMode = isDynamicTheme()
        
        // DP to Pixel
        val density = resources.displayMetrics.density
        val cardRadiusPx = cardRadiusDp * density
        
        // Kart container'ı bul (Small ve Calendar için)
        val cardContainer = view.findViewById<android.view.View>(R.id.card_container)
        
        if (cardContainer != null) {
            // Arka plan drawable'ını al ve güncelle (Köşe yuvarlama)
            val bgDrawable = cardContainer.background.mutate()
            if (bgDrawable is android.graphics.drawable.GradientDrawable) {
                bgDrawable.cornerRadius = cardRadiusPx
            }
            
            applyOverlayAndGradient(
                root = view,
                opacityPercent = opacityPercent,
                cardRadiusPx = cardRadiusPx,
                bgColorMode = bgColorMode,
                gradientMode = gradientMode,
                accentColor = accentColor,
                secondaryColor = secondaryColor,
                isDynamicMode = isDynamicMode
            )
            
            // Metin renklerini güncelle
            updateTextColors(view, textColorMode, gradientMode, accentColor)
            
            // Calendar specific updates
            if (widgetType == WidgetConfigureViewModel.WidgetType.CALENDAR) {
                updateCalendarPreview(view)
            }
        }
    }
    
    private fun updateTextOnlyPreview(view: View, textColorMode: Int, textSizePct: Int) {
        // Renkler
        val primaryColor: Int
        val secondaryColor: Int
        
        when (textColorMode) {
            1 -> { // Koyu
                primaryColor = android.graphics.Color.parseColor("#CC000000")
                secondaryColor = android.graphics.Color.parseColor("#99000000")
            }
            2 -> { // Açık
                primaryColor = android.graphics.Color.parseColor("#CCFFFFFF")
                secondaryColor = android.graphics.Color.parseColor("#99FFFFFF")
            }
            else -> { // Sistem
                 val isDark = (resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK) == android.content.res.Configuration.UI_MODE_NIGHT_YES
                if (isDark) {
                    primaryColor = android.graphics.Color.parseColor("#FFFFFFFF")
                    secondaryColor = android.graphics.Color.parseColor("#E6FFFFFF")
                } else {
                    primaryColor = android.graphics.Color.parseColor("#CC000000")
                    secondaryColor = android.graphics.Color.parseColor("#99000000")
                }
            }
        }
        
        val tvTitle = view.findViewById<TextView>(R.id.tv_title)
        val tvSubtitle = view.findViewById<TextView>(R.id.tv_subtitle)
        
        tvTitle?.setTextColor(primaryColor)
        tvSubtitle?.setTextColor(secondaryColor)
        
        // Metin Boyutu - Yüzdelik değerden scale factor hesapla
        // Base sizes from provider: Title ~17sp, Content ~19.5sp
        val scaleFactor = (textSizePct.coerceIn(80, 140) / 100f)
        
        tvTitle?.setTextSize(TypedValue.COMPLEX_UNIT_SP, 17f * scaleFactor)
        tvSubtitle?.setTextSize(TypedValue.COMPLEX_UNIT_SP, 19.5f * scaleFactor)
    }
    
    private fun updateCalendarPreview(view: View) {
        val dateDisplayMode = getDropdownIndex(dropdownDateDisplayMode)
        val hijriBold = getDropdownIndex(dropdownHijriFontStyle) == 1
        val gregorianBold = getDropdownIndex(dropdownGregorianFontStyle) == 1
        
        val tvHijri = view.findViewById<TextView>(R.id.tv_hijri_date)
        val tvGregorian = view.findViewById<TextView>(R.id.tv_gregorian_date)
        
        val hijriText = "10 Cemaziyelahir 1447"
        val gregorianText = "2 Aralık 2025"
        
        fun setStyle(tv: TextView?, text: String, isBold: Boolean) {
            tv ?: return
            val spannable = SpannableString(text)
            if (isBold) {
                spannable.setSpan(StyleSpan(Typeface.BOLD), 0, text.length, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE)
            } else {
                // Light simulation
                spannable.setSpan(StyleSpan(Typeface.NORMAL), 0, text.length, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE)
            }
            tv.text = spannable
        }
        
        when (dateDisplayMode) {
            0 -> { // Her İkisi
                tvHijri?.visibility = View.VISIBLE
                tvGregorian?.visibility = View.VISIBLE
                setStyle(tvHijri, hijriText, hijriBold)
                setStyle(tvGregorian, gregorianText, gregorianBold)
            }
            1 -> { // Sadece Hicri
                tvHijri?.visibility = View.VISIBLE
                tvGregorian?.visibility = View.GONE
                setStyle(tvHijri, hijriText, hijriBold)
            }
            2 -> { // Sadece Miladi
                tvHijri?.visibility = View.GONE
                tvGregorian?.visibility = View.VISIBLE
                setStyle(tvGregorian, gregorianText, gregorianBold)
            }
        }
    }
    
    private fun updateTextColors(view: android.view.View, mode: Int, gradientMode: Int, accentColor: Int) {
        val tvTitle = view.findViewById<TextView>(R.id.tv_title)
        val tvSubtitle = view.findViewById<TextView>(R.id.tv_subtitle)
        val tvGregorian = view.findViewById<TextView>(R.id.tv_gregorian_date)
        val tvHijri = view.findViewById<TextView>(R.id.tv_hijri_date)
        
        val primaryColor: Int
        val secondaryColor: Int
        
        when (mode) {
            1 -> { // Koyu (Metin koyu, yani açık arkaplan için)
                primaryColor = android.graphics.Color.parseColor("#CC000000")
                secondaryColor = android.graphics.Color.parseColor("#99000000")
            }
            2 -> { // Açık (Metin açık, yani koyu arkaplan için)
                primaryColor = android.graphics.Color.parseColor("#CCFFFFFF")
                secondaryColor = android.graphics.Color.parseColor("#99FFFFFF")
            }
            else -> { // Sistem
                // Widget provider mantığına göre: gradientMode == 2 (renkli) ise accentColor'ın koyuluğuna göre belirle
                val isDark = if (gradientMode == 2) {
                    isColorDark(accentColor)
                } else {
                    (resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK) == android.content.res.Configuration.UI_MODE_NIGHT_YES
                }
                if (isDark) {
                    primaryColor = android.graphics.Color.parseColor("#FFFFFFFF")
                    secondaryColor = android.graphics.Color.parseColor("#E6FFFFFF")
                } else {
                    primaryColor = android.graphics.Color.parseColor("#CC000000")
                    secondaryColor = android.graphics.Color.parseColor("#99000000")
                }
            }
        }
        
        tvTitle?.setTextColor(primaryColor)
        tvSubtitle?.setTextColor(secondaryColor)
        tvGregorian?.setTextColor(secondaryColor)
        tvHijri?.setTextColor(primaryColor)
    }
    
    private fun isColorDark(color: Int): Boolean {
        val darkness = 1.0 - (
            0.299 * android.graphics.Color.red(color).toDouble() +
            0.587 * android.graphics.Color.green(color).toDouble() +
            0.114 * android.graphics.Color.blue(color).toDouble()
        ) / 255.0
        return darkness >= 0.5
    }
    
    private fun applyOverlayAndGradient(
        root: View,
        opacityPercent: Int,
        cardRadiusPx: Float,
        bgColorMode: Int,
        gradientMode: Int,
        accentColor: Int,
        secondaryColor: Int?,
        isDynamicMode: Boolean
    ) {
        val overlay = root.findViewById<ImageView>(R.id.bg_card_overlay)
        val gradientOverlay = root.findViewById<ImageView>(R.id.gradient_overlay)

        val overlayAlpha = (opacityPercent.coerceIn(0, 100) * 255 / 100)
        
        // Widget provider mantığına göre:
        // gradientMode == 2 (renkli) -> overlay renkli olur, gradientOverlay gizlenir
        // gradientMode == 1 (gradyan) -> overlay normal olur, gradientOverlay gösterilir
        // gradientMode == 0 (kapalı) -> overlay normal olur, gradientOverlay gizlenir
        
        if (gradientMode == 2) {
            // Renkli mod: overlay'in kendisi renkli olmalı
            if (isDynamicMode && secondaryColor != null) {
                // İkincil renk varsa gradient renkli overlay
                overlay?.setImageDrawable(createColoredGradientOverlayDrawable(
                    cardRadiusPx, accentColor, secondaryColor, overlayAlpha
                ))
            } else {
                // Tek renkli overlay
                overlay?.setImageDrawable(createColoredOverlayDrawable(
                    cardRadiusPx, accentColor, overlayAlpha
                ))
            }
            overlay?.alpha = 1f
            // Gradient overlay'i gizle
            gradientOverlay?.setImageDrawable(null)
            gradientOverlay?.visibility = View.GONE
        } else {
            // Normal mod: overlay beyaz/siyah
            overlay?.setImageDrawable(createOverlayDrawable(cardRadiusPx, overlayAlpha, bgColorMode))
            overlay?.alpha = 1f
            
            // Gradient overlay sadece gradientMode == 1 olduğunda gösterilir
            if (gradientMode == 1) {
                val gradientDrawable = createTopGradientDrawable(cardRadiusPx, accentColor)
                gradientOverlay?.setImageDrawable(gradientDrawable)
                gradientOverlay?.visibility = View.VISIBLE
            } else {
                gradientOverlay?.setImageDrawable(null)
                gradientOverlay?.visibility = View.GONE
            }
        }
    }

    private fun createOverlayDrawable(
        cardRadiusPx: Float,
        overlayAlpha: Int,
        bgColorMode: Int
    ): GradientDrawable {
        val drawable = GradientDrawable()
        drawable.cornerRadius = cardRadiusPx
        val isNightMode = when (bgColorMode) {
            1 -> false
            2 -> true
            else -> (resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK) == android.content.res.Configuration.UI_MODE_NIGHT_YES
        }
        val baseColor = if (isNightMode) android.graphics.Color.BLACK else android.graphics.Color.WHITE
        drawable.setColor(ColorUtils.setAlphaComponent(baseColor, overlayAlpha.coerceIn(0, 255)))
        return drawable
    }

    private fun createColoredOverlayDrawable(
        cardRadiusPx: Float,
        accentColor: Int,
        overlayAlpha: Int
    ): GradientDrawable {
        val drawable = GradientDrawable()
        drawable.cornerRadius = cardRadiusPx
        val coloredOverlay = ColorUtils.setAlphaComponent(
            accentColor,
            overlayAlpha.coerceIn(0, 255)
        )
        drawable.setColor(coloredOverlay)
        return drawable
    }

    private fun createColoredGradientOverlayDrawable(
        cardRadiusPx: Float,
        primaryColor: Int,
        secondaryColor: Int,
        overlayAlpha: Int
    ): GradientDrawable {
        val alpha = overlayAlpha.coerceIn(0, 255)
        val start = ColorUtils.setAlphaComponent(primaryColor, alpha)
        val end = ColorUtils.setAlphaComponent(secondaryColor, alpha)
        return GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM, intArrayOf(start, end)).apply {
            cornerRadius = cardRadiusPx
        }
    }

    private fun createTopGradientDrawable(cardRadiusPx: Float, accentColor: Int): GradientDrawable {
        val start = ColorUtils.setAlphaComponent(accentColor, (0.55f * 255).toInt())
        val end = ColorUtils.setAlphaComponent(accentColor, 0)
        return GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM, intArrayOf(start, end)).apply {
            cornerRadius = cardRadiusPx
        }
    }
    
    private fun saveConfiguration() {
        // TextOnly widget için sadece metin rengi kaydedilir, diğerleri varsayılan değerler kullanılır
        val textColorMode = getDropdownIndex(textColorModeDropdown)
        
        val cardOpacity: Int
        val gradientMode: Int
        val cardRadius: Int
        val bgColorMode: Int
        
        // Calendar Specific
        var dateDisplayMode = 0
        var hijriFontStyle = 0
        var gregorianFontStyle = 1
        
        // TextOnly Specific
        var textSizePct = 100
        
        if (widgetType == WidgetConfigureViewModel.WidgetType.TEXT_ONLY) {
            // TextOnly widget: Diğer ayarlar varsayılan değerler
            cardOpacity = 204 // Varsayılan opaklık
            gradientMode = 0 // Kapalı
            cardRadius = 0 // Köşe yarıçapı yok
            bgColorMode = 0 // Sistem
            textSizePct = sliderTextSize.value.toInt().coerceIn(80, 140)
        } else {
            // Small ve Calendar widget: Tüm ayarlar UI'dan alınır
            val opacityPercent = opacitySlider.value.toInt()
            cardOpacity = (opacityPercent * 255 / 100).coerceIn(0, 255)
            gradientMode = getDropdownIndex(gradientModeDropdown)
            cardRadius = cardRadiusSlider.value.toInt().coerceIn(0, 120)
            bgColorMode = getDropdownIndex(bgColorModeDropdown)
            
            if (widgetType == WidgetConfigureViewModel.WidgetType.CALENDAR) {
                dateDisplayMode = getDropdownIndex(dropdownDateDisplayMode)
                hijriFontStyle = getDropdownIndex(dropdownHijriFontStyle)
                gregorianFontStyle = getDropdownIndex(dropdownGregorianFontStyle)
            }
        }
        
        // ViewModel üzerinden kaydet
        viewModel.saveWidgetSettings(
            context = this,
            appWidgetId = appWidgetId,
            widgetType = widgetType,
            cardOpacity = cardOpacity,
            gradientMode = gradientMode,
            cardRadius = cardRadius,
            textColorMode = textColorMode,
            bgColorMode = bgColorMode,
            dateDisplayMode = dateDisplayMode,
            hijriFontStyle = hijriFontStyle,
            gregorianFontStyle = gregorianFontStyle,
            textSizePct = textSizePct
        )
        
        // Widget'ı güncelle
        updateWidget()
        
        // Sonucu döndür ve kapat
        val resultValue = Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        setResult(Activity.RESULT_OK, resultValue)
        finish()
    }
    
    private fun getDropdownIndex(dropdown: AutoCompleteTextView): Int {
        val text = dropdown.text.toString()
        val adapter = dropdown.adapter
        for (i in 0 until adapter.count) {
            if (adapter.getItem(i).toString() == text) {
                return i
            }
        }
        return 0 // Varsayılan
    }

    private fun resolvePreviewDimensions(): PreviewDimensions {
        val manager = AppWidgetManager.getInstance(this)
        val options = runCatching { manager.getAppWidgetOptions(appWidgetId) }.getOrNull()
        val info = runCatching { manager.getAppWidgetInfo(appWidgetId) }.getOrNull()
        val density = resources.displayMetrics.density

        val defaultWidthDp = info?.minWidth ?: 110
        val defaultHeightDp = info?.minHeight ?: 110

        val widthDp = listOfNotNull(
            options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH),
            options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH),
            defaultWidthDp
        ).firstOrNull { it > 0 } ?: defaultWidthDp

        val heightDp = listOfNotNull(
            options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT),
            options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT),
            defaultHeightDp
        ).firstOrNull { it > 0 } ?: defaultHeightDp

        // Önizleme alanı kompakt olduğu için widget boyutunu sınırlandır
        // Maksimum genişlik: ~280dp, maksimum yükseklik: ~140dp
        val maxWidthDp = 280
        val maxHeightDp = 140
        
        val constrainedWidthDp = widthDp.coerceAtMost(maxWidthDp)
        val constrainedHeightDp = heightDp.coerceAtMost(maxHeightDp)

        val widthPx = (constrainedWidthDp * density).roundToInt().coerceAtLeast((100 * density).roundToInt())
        val heightPx = (constrainedHeightDp * density).roundToInt().coerceAtLeast((80 * density).roundToInt())

        return PreviewDimensions(widthPx, heightPx)
    }

    private fun resolveAccentColor(): Int {
        return readColorPref("flutter.current_theme_color")
            ?: readColorPref("flutter.selected_theme_color")
            ?: 0xFF2196F3.toInt()
    }

    private fun resolveSecondaryColor(): Int? = readColorPref("flutter.current_secondary_color")

    private fun isDynamicTheme(): Boolean {
        val prefs = flutterPrefs()
        val mode = prefs.getString("flutter.theme_color_mode", null)
        return mode == "dynamic"
    }

    private fun readColorPref(key: String): Int? {
        val prefs = flutterPrefs()
        val any = prefs.all[key] ?: return null
        return when (any) {
            is Int -> any
            is Long -> any.toInt()
            is String -> any.toIntOrNull()
            else -> null
        }
    }

    private fun flutterPrefs(): SharedPreferences =
        getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)

    private data class PreviewDimensions(val widthPx: Int, val heightPx: Int)
    
    private fun updateWidget() {
        val manager = AppWidgetManager.getInstance(this)
        
        // Widget türüne göre ilgili provider'ı güncelle
        when (widgetType) {
            WidgetConfigureViewModel.WidgetType.SMALL -> {
                SmallPrayerWidgetProvider.updateAppWidget(
                    this,
                    manager,
                    appWidgetId
                )
            }
            WidgetConfigureViewModel.WidgetType.TEXT_ONLY -> {
                TextOnlyWidgetProvider.updateAppWidget(
                    this,
                    manager,
                    appWidgetId
                )
            }
            WidgetConfigureViewModel.WidgetType.CALENDAR -> {
                CalendarWidgetProvider.updateAppWidget(
                    this,
                    manager,
                    appWidgetId
                )
            }
        }
        
        // Tüm widget'ları güncellemek için broadcast gönder
        val updateIntent = Intent(AppWidgetManager.ACTION_APPWIDGET_UPDATE).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(appWidgetId))
        }
        when (widgetType) {
            WidgetConfigureViewModel.WidgetType.SMALL -> {
                updateIntent.component = ComponentName(this, SmallPrayerWidgetProvider::class.java)
            }
            WidgetConfigureViewModel.WidgetType.TEXT_ONLY -> {
                updateIntent.component = ComponentName(this, TextOnlyWidgetProvider::class.java)
            }
            WidgetConfigureViewModel.WidgetType.CALENDAR -> {
                updateIntent.component = ComponentName(this, CalendarWidgetProvider::class.java)
            }
        }
        sendBroadcast(updateIntent)
    }
}
