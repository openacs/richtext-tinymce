ad_library {
    Initialization for tinymce
}

::richtext::tinymce::register_urns

#
# GN: is this the right place?
#
template::util::richtext::register_editor tinymce

#
# GN: this code is quite invasive. Why is this needed?
#
if {[apm_package_installed_p xowiki]} {
    #
    # We become the preferred richtext editor for xowiki, if none was
    # chosen so far.
    #
    set preferred_editor [::parameter::get_global_value \
                              -package_key xowiki \
                              -parameter PreferredRichtextEditor]
    if {$preferred_editor eq ""} {
        ::parameter::set_global_value \
            -package_key xowiki \
            -parameter PreferredRichtextEditor \
            -value "tinymce"
    }
}


# Local variables:
#    mode: tcl
#    tcl-indent-level: 4
#    indent-tabs-mode: nil
# End:
