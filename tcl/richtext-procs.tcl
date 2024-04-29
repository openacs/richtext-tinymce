ad_library {

    Integration of TinyMCE with the richtext widget of acs-templating.

    This script defines the following two procs:

       ::richtext-tinymce::initialize_widget
       ::richtext-tinymce::render_widgets

    @author Gustaf Neumann
    @creation-date 1 Jan 2016
    @cvs-id $Id$
}

namespace eval ::richtext::tinymce {

    ad_proc -private version {} {
        return [::parameter::get_global_value \
                    -package_key richtext-tinymce \
                    -parameter Version]
    }

    ad_proc -private api_key {} {
        return [::parameter::get_global_value \
                    -package_key richtext-tinymce \
                    -parameter APIKey]
    }

    ad_proc -private cdn_host {} {
        return https://cdn.tiny.cloud
    }

    ad_proc -private base_cdn_url {} {
        set cdn_host [::richtext::tinymce::cdn_host]
        set api_key [::richtext::tinymce::api_key]
        return ${cdn_host}/1/${api_key}/tinymce
    }

    ad_proc -private base_download_url {} {
        return https://download.tiny.cloud/tinymce/community
    }

    ad_proc -private download_url {} {
        set version [::richtext::tinymce::version]
        set base_download_url [::richtext::tinymce::base_download_url]
        return ${base_download_url}/tinymce_${version}.zip
    }

    ad_proc -private lang_download_url {} {
        set version [::richtext::tinymce::version]
        set major [lindex [split $version .] 0]
        set base_download_url [::richtext::tinymce::base_download_url]
        return ${base_download_url}/languagepacks/${major}/langs.zip
    }

    ad_proc -private url {} {
        if {[file exists [::richtext::tinymce::path]]} {
            set version [::richtext::tinymce::version]
            set base_url /resources/richtext-tinymce/${version}/tinymce/js/tinymce
            return ${base_url}/tinymce.min.js"
        } else {
            set version [::richtext::tinymce::version]
            set base_url [::richtext::tinymce::base_cdn_url]
            return ${base_url}/${version}/tinymce.min.js
        }
    }

    ad_proc -private base_path {} {
        set root_dir [acs_package_root_dir richtext-tinymce]
        set version [::richtext::tinymce::version]
        return ${root_dir}/www/resources/${version}/tinymce/js/tinymce
    }

    ad_proc -private langs_path {} {
        return [::richtext::tinymce::base_path]/langs
    }

    ad_proc -private path {} {
        return [::richtext::tinymce::base_path]/tinymce.min.js
    }

    ad_proc -private resource_info {} {
        @return a dict in "resource_info" format, compatible with
                other api and templates on the system.

        @see util::resources::can_install_locally
        @see util::resources::is_installed_locally
        @see util::resources::download
        @see util::resources::version_dir
    } {
        set version [::richtext::tinymce::version]

        #
        # Setup variables for access via CDN vs. local resources.
        #
        set resourceDir [acs_package_root_dir richtext-tinymce/www/resources]
        set resourceUrl /resources/richtext-tinymce
        set cdn         [::richtext::tinymce::cdn_host]

        if {[file exists [::richtext::tinymce::path]]} {
            set prefix  [::richtext::tinymce::base_path]
            set cdnHost ""
        } else {
            set base_url [::richtext::tinymce::base_cdn_url]
            set prefix ${base_url}/${version}
            set cdnHost [dict get [ns_parseurl $cdn] host]
        }

        #
        # Return the dict with at least the required fields
        #
        lappend result \
            resourceName "TinyMCE" \
            resourceDir $resourceDir \
            cdn $cdn \
            cdnHost $cdnHost \
            prefix $prefix \
            cssFiles {} \
            jsFiles  {} \
            extraFiles {} \
            downloadURLs [list \
                              [::richtext::tinymce::download_url] \
                              [::richtext::tinymce::lang_download_url] \
                             ] \
            urnMap {} \
            versionCheckURL https://www.tiny.cloud/tinymce/

        return $result
    }

    ad_proc -private download {} {

        Download the editor package for the configured version and put
        it into a directory structure similar to the CDN structure to
        allow installation of multiple versions. When the local
        structure is available, it will be used by initialize_widget.

        Notice, that for this automated download, the "unzip" program
        must be installed and $::acs::rootdir/packages/www must be
        writable by the web server.

    } {
        set version [::richtext::tinymce::version]

        set resource_info [::richtext::tinymce::resource_info]

        ::util::resources::download \
            -resource_info $resource_info \
            -version_dir $version

        set resourceDir [dict get $resource_info resourceDir]

        #
        # Do we have unzip installed?
        #
        set unzip [::util::which unzip]
        if {$unzip eq ""} {
            error "can't install TinyMCE locally; no unzip program found on PATH"
        }

        #
        # Do we have a writable output directory under resourceDir?
        #
        if {![file isdirectory $resourceDir/$version]} {
            file mkdir $resourceDir/$version
        }
        if {![file writable $resourceDir/$version]} {
            error "directory $resourceDir/$version is not writable"
        }

        #
        # So far, everything is fine, unpack the editor package.
        #
        foreach url [dict get $resource_info downloadURLs] {
            set fn [file tail $url]
            util::unzip -overwrite -source $resourceDir/$version/$fn -destination $resourceDir/$version
        }

        #
        # Move the language pack where the editor expects it to be.
        #
        set langs_path [::richtext::tinymce::langs_path]
        #
        # The download zip contains a langs folder, which contains a
        # readme file, hence the -force.
        #
        file delete -force -- $langs_path
        file rename $resourceDir/$version/langs $langs_path
    }

    ad_proc -private serialize_options {options} {
        Converts an options dict into a JSON value suitable to
        configure TinyMCE.
    } {
        #
        # Serialize to JSON
        #

        set pairslist [list]

        #
        # Note: we may need to use a more competent JSON serialization
        # to account for e.g. arrays and such, but so far this is
        # enough.
        #
        foreach {key value} $options {
            if  {[string is boolean -strict $value] || [string is double -strict $value]} {
                lappend pairslist "${key}:${value}"
            } else {
                lappend pairslist "${key}:\"${value}\""
            }
        }

        return [join $pairslist ,]
    }

    ad_proc -private default_config {} {
        Returns the default configuration in dict format.
    } {
        #
        # This is the bare minimum config we need: specify a license
        # and turn of the ad link.
        #
        set tinymce_hardcoded_config {
            license_key gpl
            promotion false
        }
        set tinymce_default_config [::parameter::get_global_value \
                                        -package_key richtext-tinymce \
                                        -parameter DefaultConfig]

        return [dict merge \
                    $tinymce_hardcoded_config \
                    $tinymce_default_config]
    }

    ad_proc initialize_widget {
        -form_id
        -text_id
        {-options {}}
    } {

        Initialize an TinyMCE richtext editor widget.
        This proc defines finally the global variable

        ::acs_blank_master(tinymce.config)

    } {
        ns_log debug "Initialize TinyMCE instance with <$options>"
        #
        # Build specific javascript configurations from widget options
        # and system parameters
        #

        #
        # Apply widget options to the system configuration. Local
        # configuration will have the precedence and override system
        # values.
        #
        set options [dict merge \
                         [::richtext::tinymce::default_config] \
                         $options]
        ns_log debug "tinymce: options $options"

        #
        # Build the selectors for the textareas where we apply tinyMCE
        #
        set tinymce_selectors [list]
        foreach htmlarea_id [lsort -unique $::acs_blank_master__htmlareas] {
            lappend tinymce_selectors "#$htmlarea_id"
        }
        lappend options selector [join $tinymce_selectors ,]

        ::richtext::tinymce::add_editor \
            -reset_config -config $options

        return
    }

    ad_proc ::richtext::tinymce::add_editor {
        {-order 10}
        -reset_config:boolean
        {-config ""}
    } {
        Add the necessary JavaScript and other files to the current
        page. The naming is modeled after "add_script", "add_css",
        ... but is intended to care about everything necessary,
        including the content security policies.

        This function can be as well used from other packages, such
        e.g. from the xowiki form-fields, which provide a much higher
        customization.

        @param config local editor configuration in dict format. This
                       will override any setting coming from system
                       parameters.
        @param order an additional offset to the loading order for
                     this resource, useful to control dependencies.
                     @param config a custom configuration dict for
                     this editor, which will be either merged or used
                     in place of the configuration coming from
                     parameters, depending pn the reset_config
                     flag. The syntax is the same of the DefaultConfig
                     parameter in this package.
        @param reset_config when set, resets the editor configuration
                            coming from system parameters and only use
                            that we provide locally.
    } {
        ::template::head::add_javascript \
            -src [::richtext::tinymce::url] \
            -order ${order}.1

        set local_installation_p [file exists [::richtext::tinymce::path]]
        if {!$local_installation_p} {
            set cdn_host [::richtext::tinymce::cdn_host]
            security::csp::require connect-src $cdn_host
            security::csp::require script-src $cdn_host
            security::csp::require style-src $cdn_host
            security::csp::require img-src $cdn_host
        }

        set default_config [expr {$reset_config_p ? "" : [::richtext::tinymce::default_config]}]

        set config [dict merge \
                        [list language [ad_conn language]] \
                        $default_config \
                        $config]

        set editor_config [::richtext::tinymce::serialize_options $config]

        template::add_script -script [subst -nocommands {
            tinyMCE.init({${editor_config}});
        }] -section body
    }

    ad_proc render_widgets {} {
        Mandatory implementation of the richtext::* contract, which may
        go away at some point.

        @see richtext::tinymce::add_editor
    } {
    }
}

# Local variables:
#    mode: tcl
#    tcl-indent-level: 4
#    indent-tabs-mode: nil
# End:
