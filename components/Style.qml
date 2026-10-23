pragma Singleton

import QtQuick

QtObject {
    property bool blackTheme: true   // Matrix theme: dark = green on black, light = dark green on pale green

    // colour palette over the Matrix design: every green of this file goes through c(), which turns
    // its hue to the palette's (lightness and saturation kept, k brightens the accents of dark hues).
    // Neutral greys, reds and ambers (errors, warnings) are left as they are. "matrix" = no change.
    property string themePalette: "matrix"
    readonly property var palettes: ({
        "matrix":       { name: "Matrix",       hue: -1,    k: 1.0,  color: "#00FF41" },
        "cyberpunk":    { name: "Cyberpunk",    hue: 0.905, k: 1.05, color: "#FF2A9D" },
        "tron":         { name: "Tron",         hue: 0.505, k: 1.0,  color: "#00F0FF" },
        "ambar":        { name: "Ámbar",        hue: 0.105, k: 1.0,  color: "#FFB000" },
        "monero":       { name: "Monero",       hue: 0.068, k: 1.0,  color: "#FF6600" },
        "hielo":        { name: "Hielo",        hue: 0.585, k: 1.3,  color: "#4DA6FF" },
        "ultravioleta": { name: "Ultravioleta", hue: 0.76,  k: 1.3,  color: "#B04DFF" },
        "acido":        { name: "Ácido",        hue: 0.17,  k: 1.0,  color: "#E8FF00" },
        // no colour: greens become greys, accents white on dark and black on light
        "mono":         { name: "Blanco y negro", hue: 0, k: 1.0, color: "#FFFFFF", mono: true }
    })
    readonly property var paletteOrder: ["matrix", "cyberpunk", "tron", "ambar", "monero", "hielo", "ultravioleta", "acido", "mono"]

    function _hex2(v) {
        var x = Math.max(0, Math.min(255, Math.round(v * 255))).toString(16);
        return x.length < 2 ? "0" + x : x;
    }

    // pastel instead of neon: softer colours over any palette. Accents lose saturation and glare,
    // the dark theme's blacks lift to a dark grey and the light theme's whites dim to a soft grey.
    property bool pastel: false

    // [saturation, lightness] of a colour in pastel
    function _pastel(s, l) {
        if (blackTheme) {
            if (l < 0.2)
                return [s * 0.1, 0.085 + l * 0.55];                 // backgrounds: black -> neutral dark grey
            if (l > 0.9)
                return [s * 0.5, 0.88];                             // white text without glare
            return [s * 0.55, Math.min(0.82, 0.28 + l * 0.75)];   // accents: soft, not neon
        }
        if (l > 0.7)
            return [s * 0.12, 0.7 + (l - 0.7) * 0.6];               // whites / pale backgrounds -> neutral grey
        return [s * 0.6, l * 0.92];                                 // text and accents a bit darker
    }

    // a Matrix colour ("#rrggbb" or "#aarrggbb") in the current palette and neon / pastel
    function c(hex) {
        var p = palettes[themePalette];
        var shift = !!p && p.hue >= 0;
        if (!shift && !pastel)
            return hex;
        var col = Qt.lighter(hex, 1.0);
        var s = col.hslSaturation, h = col.hslHue, l = col.hslLightness;
        var isGreen = s >= 0.04 && h >= 0.18 && h <= 0.48;
        if (!pastel && !isGreen)
            return hex;
        if (shift && isGreen && p.mono) {
            if (blackTheme && s > 0.3 && l > 0.25 && l < 0.9)   // accents near white on dark
                l = Math.min(0.94, 0.55 + l * 0.7);
            else if (!blackTheme && s > 0.8 && l > 0.25 && l < 0.9)   // vivid accents near black on light
                l = Math.max(0.08, l * 0.35);
            s = 0;
        } else if (shift && isGreen) {
            h = p.hue;
            if (s > 0.3 && l > 0.25 && l < 0.9)   // accents only, not the tinted greys
                l = Math.min(0.9, l * p.k);
        }
        if (pastel) {
            var v = _pastel(s, l);
            s = v[0];
            l = v[1];
        }
        var o = Qt.hsla(Math.max(0, h), s, l, col.a);   // greys report hue -1
        return "#" + (col.a < 1 ? _hex2(col.a) : "") + _hex2(o.r) + _hex2(o.g) + _hex2(o.b);
    }
    property QtObject fontMedium: FontLoader { id: _fontMedium; source: "qrc:/fonts/Roboto-Medium.ttf"; }
    property QtObject fontBold: FontLoader { id: _fontBold; source: "qrc:/fonts/Roboto-Bold.ttf"; }
    property QtObject fontLight: FontLoader { id: _fontLight; source: "qrc:/fonts/Roboto-Light.ttf"; }
    property QtObject fontRegular: FontLoader { id: _fontRegular; source: "qrc:/fonts/Roboto-Regular.ttf"; }
    // XMR Sans: Roboto plus the Monero symbol at ɱ (U+0271); loaded so it can be picked anywhere, notes included
    property QtObject fontXmrLight: FontLoader { source: "qrc:/fonts/XMRSans-Light.ttf"; }
    property QtObject fontXmrRegular: FontLoader { source: "qrc:/fonts/XMRSans-Regular.ttf"; }
    property QtObject fontXmrMedium: FontLoader { source: "qrc:/fonts/XMRSans-Medium.ttf"; }
    property QtObject fontXmrBold: FontLoader { source: "qrc:/fonts/XMRSans-Bold.ttf"; }

    property QtObject fontMonoMedium: FontLoader { id: _fontMonoMedium; source: "qrc:/fonts/RobotoMono-Medium.ttf"; }
    property QtObject fontMonoBold: FontLoader { id: _fontMonoBold; source: "qrc:/fonts/RobotoMono-Bold.ttf"; }
    property QtObject fontMonoLight: FontLoader { id: _fontMonoLight; source: "qrc:/fonts/RobotoMono-Light.ttf"; }
    property QtObject fontMonoRegular: FontLoader { id: _fontMonoRegular; source: "qrc:/fonts/RobotoMono-Regular.ttf"; }

    property string grey: blackTheme ? c("#0A1F0A") : c("#BDC4BE")
    property string orange: blackTheme ? c("#00FF41") : c("#00A82D")
    // text that must stand out: white on dark, accent green on light
    property string textAccent: blackTheme ? c("#FFFFFF") : orange
    property string white: blackTheme ? c("#00FF41") : c("#FFFFFF")
    property string green: blackTheme ? c("#00FF41") : c("#00A82D")
    property string moneroGrey: blackTheme ? c("#0D2B0D") : c("#ADB6AF")
    property string warningColor: c("#ADFF2F")

    property string defaultFontColor: blackTheme ? _b_defaultFontColor : _w_defaultFontColor
    property string dimmedFontColor: blackTheme ? _b_dimmedFontColor : _w_dimmedFontColor
    property string lightGreyFontColor: blackTheme ? _b_lightGreyFontColor : _w_lightGreyFontColor
    property string errorColor: blackTheme ? _b_errorColor : _w_errorColor
    property string textSelectionColor: blackTheme ? _b_textSelectionColor : _w_textSelectionColor
    property string textSelectedColor: blackTheme ? _b_textSelectedColor : _w_textSelectedColor

    property string inputBoxBackground: blackTheme ? _b_inputBoxBackground : _w_inputBoxBackground
    property string inputBoxBackgroundDisabled: blackTheme ? _b_inputBoxBackgroundDisabled : _w_inputBoxBackgroundDisabled
    property string inputBoxBackgroundError: blackTheme ? _b_inputBoxBackgroundError : _w_inputBoxBackgroundError
    property string inputBoxColor: blackTheme ? _b_inputBoxColor : _w_inputBoxColor
    property string legacy_placeholderFontColor: blackTheme ? _b_legacy_placeholderFontColor : _w_legacy_placeholderFontColor
    property string inputBorderColorActive: blackTheme ? _b_inputBorderColorActive : _w_inputBorderColorActive
    property string inputBorderColorInActive: blackTheme ? _b_inputBorderColorInActive : _w_inputBorderColorInActive
    property string inputBorderColorInvalid: blackTheme ? _b_inputBorderColorInvalid : _w_inputBorderColorInvalid

    property string buttonBackgroundColor: blackTheme ? _b_buttonBackgroundColor : _w_buttonBackgroundColor
    property string buttonBackgroundColorHover: blackTheme ? _b_buttonBackgroundColorHover : _w_buttonBackgroundColorHover
    property string buttonBackgroundColorDisabled: blackTheme ? _b_buttonBackgroundColorDisabled : _w_buttonBackgroundColorDisabled
    property string buttonBackgroundColorDisabledHover: blackTheme ? _b_buttonBackgroundColorDisabledHover : _w_buttonBackgroundColorDisabledHover
    property string buttonInlineBackgroundColor: blackTheme ? _b_buttonInlineBackgroundColor : _w_buttonInlineBackgroundColor
    property string buttonInlineBackgroundColorHover: blackTheme ? _b_buttonInlineBackgroundColorHover : _w_buttonInlineBackgroundColorHover
    property string buttonTextColor: blackTheme ? _b_buttonTextColor : _w_buttonTextColor
    property string buttonTextColorDisabled: blackTheme ? _b_buttonTextColorDisabled : _w_buttonTextColorDisabled
    property string buttonSecondaryBackgroundColor: blackTheme ? _b_buttonSecondaryBackgroundColor : _w_buttonSecondaryBackgroundColor
    property string buttonSecondaryBackgroundColorHover: blackTheme ? _b_buttonSecondaryBackgroundColorHover : _w_buttonSecondaryBackgroundColorHover
    property string buttonSecondaryTextColor: blackTheme ? _b_buttonSecondaryTextColor : _w_buttonSecondaryTextColor
    property string dividerColor: blackTheme ? _b_dividerColor : _w_dividerColor
    property real dividerOpacity: blackTheme ? _b_dividerOpacity : _w_dividerOpacity

    property string titleBarBackgroundGradientStart: blackTheme ? _b_titleBarBackgroundGradientStart : _w_titleBarBackgroundGradientStart
    property string titleBarBackgroundGradientStop: blackTheme ? _b_titleBarBackgroundGradientStop : _w_titleBarBackgroundGradientStop
    property string titleBarBackgroundBorderColor: blackTheme ? _b_titleBarBackgroundBorderColor : _w_titleBarBackgroundBorderColor
    property string titleBarLogoSource: blackTheme ? _b_titleBarLogoSource : _w_titleBarLogoSource
    property string titleBarMinimizeSource: blackTheme ? _b_titleBarMinimizeSource : _w_titleBarMinimizeSource
    property string titleBarFullscreenSource: blackTheme ? _b_titleBarFullscreenSource : _w_titleBarFullscreenSource
    property string titleBarCloseSource: blackTheme ? _b_titleBarCloseSource : _w_titleBarCloseSource
    property string titleBarButtonHoverColor: blackTheme ? _b_titleBarButtonHoverColor : _w_titleBarButtonHoverColor

    property string wizardBackgroundGradientStart: blackTheme ? _b_wizardBackgroundGradientStart : _w_wizardBackgroundGradientStart
    property string middlePanelBackgroundGradientStart: blackTheme ? _b_middlePanelBackgroundGradientStart : _w_middlePanelBackgroundGradientStart
    property string middlePanelBackgroundGradientStop: blackTheme ? _b_middlePanelBackgroundGradientStop : _w_middlePanelBackgroundGradientStop
    property string middlePanelBackgroundColor: blackTheme ? _b_middlePanelBackgroundColor : _w_middlePanelBackgroundColor
    property string menuButtonFallbackBackgroundColor: blackTheme ? _b_menuButtonFallbackBackgroundColor : _w_menuButtonFallbackBackgroundColor
    property string menuButtonGradientStart: blackTheme ? _b_menuButtonGradientStart : _w_menuButtonGradientStart
    property string menuButtonGradientStop: blackTheme ? _b_menuButtonGradientStop : _w_menuButtonGradientStop
    property string menuButtonTextColor: blackTheme ? _b_menuButtonTextColor : _w_menuButtonTextColor
    property string menuButtonImageRightColorActive: blackTheme ? _b_menuButtonImageRightColorActive : _w_menuButtonImageRightColorActive
    property string menuButtonImageRightColor: blackTheme ? _b_menuButtonImageRightColor : _w_menuButtonImageRightColor
    property string menuButtonImageRightSource: blackTheme ? _b_menuButtonImageRightSource : _w_menuButtonImageRightSource
    property string menuButtonImageDotArrowSource: blackTheme ? _b_menuButtonImageDotArrowSource : _w_menuButtonImageDotArrowSource
    property string inlineButtonTextColor: blackTheme ? _b_inlineButtonTextColor : _w_inlineButtonTextColor
    property string inlineButtonBorderColor: blackTheme ? _b_inlineButtonBorderColor : _w_inlineButtonBorderColor
    property string appWindowBackgroundColor: blackTheme ? _b_appWindowBackgroundColor : _w_appWindowBackgroundColor
    property string appWindowBorderColor: blackTheme ? _b_appWindowBorderColor : _w_appWindowBorderColor
    property bool progressBarProgressTextBold: blackTheme ? _b_progressBarProgressTextBold : _w_progressBarProgressTextBold
    property string progressBarBackgroundColor: blackTheme ? _b_progressBarBackgroundColor : _w_progressBarBackgroundColor
    property string leftPanelBackgroundGradientStart: blackTheme ? _b_leftPanelBackgroundGradientStart : _w_leftPanelBackgroundGradientStart
    property string leftPanelBackgroundGradientStop: blackTheme ? _b_leftPanelBackgroundGradientStop : _w_leftPanelBackgroundGradientStop
    property string historyHeaderTextColor: blackTheme ? _b_historyHeaderTextColor : _w_historyHeaderTextColor
    property var accountColors: blackTheme ? _b_accountColors : _w_accountColors

    property string _b_defaultFontColor: c("#ECECEC")
    property string _b_dimmedFontColor: c("#8C8C8C")
    property string _b_lightGreyFontColor: c("#BDBDBD")
    property string _b_errorColor: c("#FF3B3B")
    property string _b_textSelectionColor: c("#005F0B")
    property string _b_textSelectedColor: c("#FFFFFF")

    property string _b_inputBoxBackground: c("#000000")
    property string _b_inputBoxBackgroundDisabled: c("#0A140A")
    property string _b_inputBoxBackgroundError: c("#2A0000")
    property string _b_inputBoxColor: c("#ECECEC")
    property string _b_legacy_placeholderFontColor: c("#6E6E6E")
    property string _b_inputBorderColorActive: c("#00FF41")
    property string _b_inputBorderColorInActive: c("#005F0B")
    property string _b_inputBorderColorInvalid: c("#FF3B3B")

    property string _b_buttonBackgroundColor: c("#003B00")
    property string _b_buttonBackgroundColorHover: c("#005F0B")
    property string _b_buttonBackgroundColorDisabled: c("#0A140A")
    property string _b_buttonBackgroundColorDisabledHover: c("#0F1F0F")
    property string _b_buttonInlineBackgroundColor: c("#0A1F0A")
    property string _b_buttonInlineBackgroundColorHover: c("#003B00")
    property string _b_buttonTextColor: c("#FFFFFF")
    property string _b_buttonTextColorDisabled: c("#5A5A5A")
    property string _b_buttonSecondaryBackgroundColor: c("#0A1F0A")
    property string _b_buttonSecondaryBackgroundColorHover: c("#003B00")
    property string _b_buttonSecondaryTextColor: c("#D0D0D0")
    property string _b_dividerColor: c("#00FF41")
    property real _b_dividerOpacity: 0.20

    property string _b_titleBarBackgroundGradientStart: c("#1B1F1C")
    property string _b_titleBarBackgroundGradientStop: c("#151816")
    property string _b_titleBarBackgroundBorderColor: c("#003B00")
    property string _b_titleBarLogoSource: "qrc:///images/logos/titlebarLogo.png"
    property string _b_titleBarMinimizeSource: "qrc:///images/window/minimize.svg"
    property string _b_titleBarFullscreenSource: "qrc:///images/window/fullscreen.svg"
    property string _b_titleBarCloseSource: "qrc:///images/window/close.svg"
    property string _b_titleBarButtonHoverColor: c("#2000FF41")

    property string _b_wizardBackgroundGradientStart: c("#000000")
    property string _b_middlePanelBackgroundGradientStart: c("#020A02")
    property string _b_middlePanelBackgroundGradientStop: c("#000000")
    property string _b_middlePanelBackgroundColor: c("#010601")
    property string _b_menuButtonFallbackBackgroundColor: c("#1000FF41")
    property string _b_menuButtonGradientStart: c("#2000FF41")
    property string _b_menuButtonGradientStop: c("#00000000")
    property string _b_menuButtonTextColor: c("#ECECEC")
    property string _b_menuButtonImageRightColorActive: c("#00FF41")
    property string _b_menuButtonImageRightColor: c("#008F11")
    property string _b_menuButtonImageRightSource: "qrc:///images/icons/right.svg"
    property string _b_menuButtonImageDotArrowSource: "qrc:///images/icons/arrow-right-medium-white.png"
    property string _b_inlineButtonTextColor: c("#ECECEC")
    property string _b_inlineButtonBorderColor: c("#003B00")
    property string _b_appWindowBackgroundColor: c("#000000")
    property string _b_appWindowBorderColor: c("#003B00")
    property bool _b_progressBarProgressTextBold: true
    property string _b_progressBarBackgroundColor: c("#2400FF41")
    property string _b_leftPanelBackgroundGradientStart: c("#020A02")
    property string _b_leftPanelBackgroundGradientStop: c("#000000")
    property string _b_historyHeaderTextColor: c("#A8A8A8")
    property var _b_accountColors: [c("#00FF41"), c("#00C832"), c("#39FF14"), c("#008F11"), c("#7CFC00"), c("#00E676"), c("#32CD32"), c("#005F0B")]

     
property string _w_defaultFontColor: c("#003B00")
    
property string _w_dimmedFontColor: c("#2E6B3A")
    
property string _w_lightGreyFontColor: c("#1F5A2B")
    
property string _w_errorColor: c("#D32F2F")
    
property string _w_textSelectionColor: c("#9CF0AE")
    
property string _w_textSelectedColor: c("#003B00")
    
property string _w_inputBoxBackground: c("#E2E6E3")
    
property string _w_inputBoxBackgroundDisabled: c("#D2D8D3")
    
property string _w_inputBoxBackgroundError: c("#FFDDDD")
    
property string _w_inputBoxColor: c("#003B00")
    
property string _w_legacy_placeholderFontColor: c("#7FA889")
    
property string _w_inputBorderColorActive: c("#00A82D")
    
property string _w_inputBorderColorInActive: c("#A5D6AE")
    
property string _w_inputBorderColorInvalid: c("#D32F2F")
    
property string _w_buttonBackgroundColor: c("#00A82D")
    
property string _w_buttonBackgroundColorHover: c("#008F11")
    
property string _w_buttonBackgroundColorDisabled: c("#C5DCC9")
    
property string _w_buttonBackgroundColorDisabledHover: c("#B5CFBA")
    
property string _w_buttonInlineBackgroundColor: c("#C2CBC4")
    
property string _w_buttonInlineBackgroundColorHover: c("#B4BEB6")
    
property string _w_buttonTextColor: c("#FFFFFF")
    
property string _w_buttonTextColorDisabled: c("#5E7A64")
    
property string _w_buttonSecondaryBackgroundColor: c("#C2CBC4")
    
property string _w_buttonSecondaryBackgroundColorHover: c("#B4BEB6")
    
property string _w_buttonSecondaryTextColor: c("#003B00")
    
property string _w_dividerColor: c("#003B00")
    
property real _w_dividerOpacity: 0.20
    
property string _w_titleBarBackgroundGradientStart: c("#CDD3CE")
    
property string _w_titleBarBackgroundGradientStop: c("#C4CAC5")
    
property string _w_titleBarBackgroundBorderColor: c("#AAB3AC")
    
property string _w_titleBarLogoSource: "qrc:///images/themes/white/titlebarLogo.png"
    
property string _w_titleBarMinimizeSource: "qrc:///images/themes/white/minimize.svg"
    
property string _w_titleBarFullscreenSource: "qrc:///images/themes/white/fullscreen.svg"
    
property string _w_titleBarCloseSource: "qrc:///images/themes/white/close.svg"
    
property string _w_titleBarButtonHoverColor: c("#1100A82D")
    
property string _w_wizardBackgroundGradientStart: c("#D3D8D4")
    
property string _w_middlePanelBackgroundGradientStart: c("#D3D8D4")
    
property string _w_middlePanelBackgroundGradientStop: c("#C7CDC8")
    
property string _w_middlePanelBackgroundColor: c("#CDD3CE")
    
property string _w_menuButtonFallbackBackgroundColor: c("#0900A82D")
    
property string _w_menuButtonGradientStart: c("#1400A82D")
    
property string _w_menuButtonGradientStop: c("#10FFFFFF")
    
property string _w_menuButtonTextColor: c("#2E6B3A")
    
property string _w_menuButtonImageRightSource: "qrc:///images/icons/right.svg"
    
property string _w_menuButtonImageRightColorActive: c("#00A82D")
    
property string _w_menuButtonImageRightColor: c("#5E8A66")
    
property string _w_menuButtonImageDotArrowSource: "qrc:///images/icons/arrow-right-medium-white.png"
    
property string _w_inlineButtonTextColor: c("#003B00")
    
property string _w_inlineButtonBorderColor: "transparent"
    
property string _w_appWindowBackgroundColor: c("#CDD3CE")
    
property string _w_appWindowBorderColor: c("#AAB3AC")
    
property bool _w_progressBarProgressTextBold: false
    
property string _w_progressBarBackgroundColor: c("#2400A82D")
    
property string _w_leftPanelBackgroundGradientStart: c("#CBD1CC")
    
property string _w_leftPanelBackgroundGradientStop: c("#BFC6C0")
    
property string _w_historyHeaderTextColor: c("#1F5A2B")
    
property var _w_accountColors: [c("#00A82D"), c("#008F11"), c("#2E7D32"), c("#1B5E20"), c("#00C853"), c("#388E3C"), c("#43A047"), c("#006400"), c("#2E6B3A")]
}
