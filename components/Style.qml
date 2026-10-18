pragma Singleton

import QtQuick

QtObject {
    property bool blackTheme: true   // Matrix theme: dark = green on black, light = dark green on pale green
    property QtObject fontMedium: FontLoader { id: _fontMedium; source: "qrc:/fonts/Roboto-Medium.ttf"; }
    property QtObject fontBold: FontLoader { id: _fontBold; source: "qrc:/fonts/Roboto-Bold.ttf"; }
    property QtObject fontLight: FontLoader { id: _fontLight; source: "qrc:/fonts/Roboto-Light.ttf"; }
    property QtObject fontRegular: FontLoader { id: _fontRegular; source: "qrc:/fonts/Roboto-Regular.ttf"; }

    property QtObject fontMonoMedium: FontLoader { id: _fontMonoMedium; source: "qrc:/fonts/RobotoMono-Medium.ttf"; }
    property QtObject fontMonoBold: FontLoader { id: _fontMonoBold; source: "qrc:/fonts/RobotoMono-Bold.ttf"; }
    property QtObject fontMonoLight: FontLoader { id: _fontMonoLight; source: "qrc:/fonts/RobotoMono-Light.ttf"; }
    property QtObject fontMonoRegular: FontLoader { id: _fontMonoRegular; source: "qrc:/fonts/RobotoMono-Regular.ttf"; }

    property string grey: blackTheme ? "#0A1F0A" : "#BDC4BE"
    property string orange: blackTheme ? "#00FF41" : "#00A82D"
    // text that must stand out: white on dark, accent green on light
    property string textAccent: blackTheme ? "#FFFFFF" : orange
    property string white: blackTheme ? "#00FF41" : "#FFFFFF"
    property string green: blackTheme ? "#00FF41" : "#00A82D"
    property string moneroGrey: blackTheme ? "#0D2B0D" : "#ADB6AF"
    property string warningColor: "#ADFF2F"

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

    property string _b_defaultFontColor: "#ECECEC"
    property string _b_dimmedFontColor: "#8C8C8C"
    property string _b_lightGreyFontColor: "#BDBDBD"
    property string _b_errorColor: "#FF3B3B"
    property string _b_textSelectionColor: "#005F0B"
    property string _b_textSelectedColor: "#FFFFFF"

    property string _b_inputBoxBackground: "#000000"
    property string _b_inputBoxBackgroundDisabled: "#0A140A"
    property string _b_inputBoxBackgroundError: "#2A0000"
    property string _b_inputBoxColor: "#ECECEC"
    property string _b_legacy_placeholderFontColor: "#6E6E6E"
    property string _b_inputBorderColorActive: "#00FF41"
    property string _b_inputBorderColorInActive: "#005F0B"
    property string _b_inputBorderColorInvalid: "#FF3B3B"

    property string _b_buttonBackgroundColor: "#003B00"
    property string _b_buttonBackgroundColorHover: "#005F0B"
    property string _b_buttonBackgroundColorDisabled: "#0A140A"
    property string _b_buttonBackgroundColorDisabledHover: "#0F1F0F"
    property string _b_buttonInlineBackgroundColor: "#0A1F0A"
    property string _b_buttonInlineBackgroundColorHover: "#003B00"
    property string _b_buttonTextColor: "#FFFFFF"
    property string _b_buttonTextColorDisabled: "#5A5A5A"
    property string _b_buttonSecondaryBackgroundColor: "#0A1F0A"
    property string _b_buttonSecondaryBackgroundColorHover: "#003B00"
    property string _b_buttonSecondaryTextColor: "#D0D0D0"
    property string _b_dividerColor: "#00FF41"
    property real _b_dividerOpacity: 0.20

    property string _b_titleBarBackgroundGradientStart: "#1B1F1C"
    property string _b_titleBarBackgroundGradientStop: "#151816"
    property string _b_titleBarBackgroundBorderColor: "#003B00"
    property string _b_titleBarLogoSource: "qrc:///images/titlebarLogo.png"
    property string _b_titleBarMinimizeSource: "qrc:///images/minimize.svg"
    property string _b_titleBarFullscreenSource: "qrc:///images/fullscreen.svg"
    property string _b_titleBarCloseSource: "qrc:///images/close.svg"
    property string _b_titleBarButtonHoverColor: "#2000FF41"

    property string _b_wizardBackgroundGradientStart: "#000000"
    property string _b_middlePanelBackgroundGradientStart: "#020A02"
    property string _b_middlePanelBackgroundGradientStop: "#000000"
    property string _b_middlePanelBackgroundColor: "#010601"
    property string _b_menuButtonFallbackBackgroundColor: "#1000FF41"
    property string _b_menuButtonGradientStart: "#2000FF41"
    property string _b_menuButtonGradientStop: "#00000000"
    property string _b_menuButtonTextColor: "#ECECEC"
    property string _b_menuButtonImageRightColorActive: "#00FF41"
    property string _b_menuButtonImageRightColor: "#008F11"
    property string _b_menuButtonImageRightSource: "qrc:///images/right.svg"
    property string _b_menuButtonImageDotArrowSource: "qrc:///images/arrow-right-medium-white.png"
    property string _b_inlineButtonTextColor: "#ECECEC"
    property string _b_inlineButtonBorderColor: "#003B00"
    property string _b_appWindowBackgroundColor: "#000000"
    property string _b_appWindowBorderColor: "#003B00"
    property bool _b_progressBarProgressTextBold: true
    property string _b_progressBarBackgroundColor: "#2400FF41"
    property string _b_leftPanelBackgroundGradientStart: "#020A02"
    property string _b_leftPanelBackgroundGradientStop: "#000000"
    property string _b_historyHeaderTextColor: "#A8A8A8"
    property var _b_accountColors: ["#00FF41", "#00C832", "#39FF14", "#008F11", "#7CFC00", "#00E676", "#32CD32", "#005F0B"]

     
property string _w_defaultFontColor: "#003B00"
    
property string _w_dimmedFontColor: "#2E6B3A"
    
property string _w_lightGreyFontColor: "#1F5A2B"
    
property string _w_errorColor: "#D32F2F"
    
property string _w_textSelectionColor: "#9CF0AE"
    
property string _w_textSelectedColor: "#003B00"
    
property string _w_inputBoxBackground: "#E2E6E3"
    
property string _w_inputBoxBackgroundDisabled: "#D2D8D3"
    
property string _w_inputBoxBackgroundError: "#FFDDDD"
    
property string _w_inputBoxColor: "#003B00"
    
property string _w_legacy_placeholderFontColor: "#7FA889"
    
property string _w_inputBorderColorActive: "#00A82D"
    
property string _w_inputBorderColorInActive: "#A5D6AE"
    
property string _w_inputBorderColorInvalid: "#D32F2F"
    
property string _w_buttonBackgroundColor: "#00A82D"
    
property string _w_buttonBackgroundColorHover: "#008F11"
    
property string _w_buttonBackgroundColorDisabled: "#C5DCC9"
    
property string _w_buttonBackgroundColorDisabledHover: "#B5CFBA"
    
property string _w_buttonInlineBackgroundColor: "#C2CBC4"
    
property string _w_buttonInlineBackgroundColorHover: "#B4BEB6"
    
property string _w_buttonTextColor: "#FFFFFF"
    
property string _w_buttonTextColorDisabled: "#5E7A64"
    
property string _w_buttonSecondaryBackgroundColor: "#C2CBC4"
    
property string _w_buttonSecondaryBackgroundColorHover: "#B4BEB6"
    
property string _w_buttonSecondaryTextColor: "#003B00"
    
property string _w_dividerColor: "#003B00"
    
property real _w_dividerOpacity: 0.20
    
property string _w_titleBarBackgroundGradientStart: "#CDD3CE"
    
property string _w_titleBarBackgroundGradientStop: "#C4CAC5"
    
property string _w_titleBarBackgroundBorderColor: "#AAB3AC"
    
property string _w_titleBarLogoSource: "qrc:///images/themes/white/titlebarLogo.png"
    
property string _w_titleBarMinimizeSource: "qrc:///images/themes/white/minimize.svg"
    
property string _w_titleBarFullscreenSource: "qrc:///images/themes/white/fullscreen.svg"
    
property string _w_titleBarCloseSource: "qrc:///images/themes/white/close.svg"
    
property string _w_titleBarButtonHoverColor: "#1100A82D"
    
property string _w_wizardBackgroundGradientStart: "#D3D8D4"
    
property string _w_middlePanelBackgroundGradientStart: "#D3D8D4"
    
property string _w_middlePanelBackgroundGradientStop: "#C7CDC8"
    
property string _w_middlePanelBackgroundColor: "#CDD3CE"
    
property string _w_menuButtonFallbackBackgroundColor: "#0900A82D"
    
property string _w_menuButtonGradientStart: "#1400A82D"
    
property string _w_menuButtonGradientStop: "#10FFFFFF"
    
property string _w_menuButtonTextColor: "#2E6B3A"
    
property string _w_menuButtonImageRightSource: "qrc:///images/right.svg"
    
property string _w_menuButtonImageRightColorActive: "#00A82D"
    
property string _w_menuButtonImageRightColor: "#5E8A66"
    
property string _w_menuButtonImageDotArrowSource: "qrc:///images/arrow-right-medium-white.png"
    
property string _w_inlineButtonTextColor: "#003B00"
    
property string _w_inlineButtonBorderColor: "transparent"
    
property string _w_appWindowBackgroundColor: "#CDD3CE"
    
property string _w_appWindowBorderColor: "#AAB3AC"
    
property bool _w_progressBarProgressTextBold: false
    
property string _w_progressBarBackgroundColor: "#2400A82D"
    
property string _w_leftPanelBackgroundGradientStart: "#CBD1CC"
    
property string _w_leftPanelBackgroundGradientStop: "#BFC6C0"
    
property string _w_historyHeaderTextColor: "#1F5A2B"
    
property var _w_accountColors: ["#00A82D", "#008F11", "#2E7D32", "#1B5E20", "#00C853", "#388E3C", "#43A047", "#006400", "#2E6B3A"]
}
