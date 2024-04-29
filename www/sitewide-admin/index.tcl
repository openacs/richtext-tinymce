ad_page_contract {
    @author Gustaf Neumann

    @creation-date Aug 6, 2018
} {
    {ck_package:token ""}
}

set version [::richtext::tinymce::version]

set resource_info [::richtext::tinymce::resource_info]
set download_url download

set title "[dict get $resource_info resourceName] - Sitewide Admin"
set context [list $title]


# Local variables:
#    mode: tcl
#    tcl-indent-level: 4
#    indent-tabs-mode: nil
# End:
