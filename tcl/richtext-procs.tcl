ad_library {

    Integration of TinyMCE with the richtext widget of acs-templating.

    This script defines the following two procs:

       ::richtext-tinymce::initialize_widget
       ::richtext-tinymce::render_widgets

    @author Antonio Pisano
    @creation-date May 2024
    @cvs-id $Id$
}

namespace eval ::richtext::tinymce {
    variable parameter_info

    #
    # The TinyMCE version configuration can be tailored via the OpenACS
    # configuration file:
    #
    # ns_section ns/server/${server}/acs/fa-icons
    #        ns_param Version 7.4.1
    #
    set parameter_info {
        package_key richtext-tinymce
        parameter_name Version
        default_value 7.4.1
    }

    ad_proc resource_info {
        {-version ""}
    } {
        @return a dict in "resource_info" format, compatible with
                other API and templates on the system.

        @see util::resources::can_install_locally
        @see util::resources::is_installed_locally
        @see util::resources::download
        @see util::resources::version_segment
    } {
        variable parameter_info

        #
        # If no version is specified, use configured one
        #
        if {$version eq ""} {
            dict with parameter_info {
                set version [::parameter::get_global_value \
                                 -package_key $package_key \
                                 -parameter $parameter_name \
                                 -default $default_value]
            }
        }

        #
        # Setup variables for access via CDN vs. local resources.
        #
        #   "resourceDir"    is the absolute path in the filesystem
        #   "versionSegment" is the version-specific element both in the
        #                    URL and in the filesystem.
        #

        set resourceDir    [acs_package_root_dir richtext-tinymce/www/resources]
        set versionSegment $version
        set cdnHost        cdnjs.cloudflare.com
        set cdn            //$cdnHost/

        if {[file exists $resourceDir/$versionSegment]} {
            #
            # Local version is installed
            #
            set prefix /resources/richtext-tinymce/$versionSegment
            set cdnHost ""
            set cspMap ""
        } else {
            #
            # Use CDN
            #
            set prefix ${cdn}ajax/libs/tinymce/$versionSegment
            dict set cspMap urn:ad:js:tinymce [subst {
                connect-src $cdnHost
                script-src $cdnHost
                style-src $cdnHost
                img-src $cdnHost
            }]
        }

        dict set URNs urn:ad:js:tinymce tinymce.min.js
        dict set URNs urn:ad:css:tinymce skins/ui/oxide/skin.min.css

        set major [lindex [split $version .] 0]

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
            downloadURLs [subst {
                https://download.tiny.cloud/tinymce/community/tinymce_$version.zip
                https://download.tiny.cloud/tinymce/community/languagepacks/$major/langs.zip
            }] \
            urnMap $URNs \
            cspMap $cspMap \
            versionCheckAPI {cdn cdnjs library tinymce count 5} \
            vulnerabilityCheck {service snyk library tinymce} \
            parameterInfo $parameter_info \
            configuredVersion $version

        return $result
    }

    ad_proc -private download {
        {-version ""}
    } {

        Download the editor package for the configured version and put
        it into a directory structure similar to the CDN structure to
        allow installation of multiple versions. When the local
        structure is available, it will be used by initialize_widget.

        Notice, that for this automated download, the "unzip" program
        must be installed and $::acs::rootdir/packages/www must be
        writable by the web server.

    } {
        set resource_info  [resource_info -version $version]
        set version        [dict get $resource_info configuredVersion]
        set resourceDir    [dict get $resource_info resourceDir]
        set versionSegment [::util::resources::version_segment -resource_info $resource_info]

        ::util::resources::download -resource_info $resource_info

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
        set path $resourceDir/$versionSegment
        if {![file isdirectory $path]} {
            file mkdir $path
        }
        if {![file writable $path]} {
            error "directory $path is not writable"
        }

        #
        # So far, everything is fine, unpack the editor package.
        #
        foreach url [dict get $resource_info downloadURLs] {
            set fn [file tail $url]
            util::unzip -overwrite -source $path/$fn -destination $path
        }

        foreach f [glob \
                       $path/tinymce/js/tinymce/*.* \
                       $path/tinymce/js/tinymce/icons \
                       $path/tinymce/js/tinymce/models \
                       $path/tinymce/js/tinymce/plugins \
                       $path/tinymce/js/tinymce/skins \
                       $path/tinymce/js/tinymce/themes \
                      ] {
            file rename $f $path/[file tail $f]
        }
    }

    ad_proc -private serialize_options {options} {
        Converts an options dict into a JSON value suitable to
        configure TinyMCE.
    } {
        set pairslist [list]

        #
        # Note: we may need to use a more competent JSON serialization
        # at some point, but so far this is enough.
        #
        foreach {key value} $options {
            if  {[string is boolean -strict $value] ||
                 [string is double -strict $value] ||
                 [regexp {^(\{.*\}|\[.*\])$} $value]
             } {
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
            branding false
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
        # Build the selector for the textarea where we apply tinyMCE
        #
        lappend options selector "#${text_id}"

        ::richtext::tinymce::add_editor \
            -reset_config -config $options

        return
    }

    ad_proc ::richtext::tinymce::add_editor {
        {-order 10}
        -reset_config:boolean
        {-config ""}
        {-init:boolean true}
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
        ::template::head::add_css \
            -href urn:ad:css:tinymce \
            -order ${order}.1

        ::template::head::add_javascript \
            -src urn:ad:js:tinymce \
            -order ${order}.1

        #
        # TinyMCE transparently copy-pastes images as blobs into the
        # content.
        #
        security::csp::require img-src blob:

        if {!$init_p} {
            #
            # We just want the header stuff.
            #
            return
        }

        set default_config [expr {$reset_config_p ? "" : [::richtext::tinymce::default_config]}]

        #
        # Useful e.g. for plugins to know where to point to or adapt
        # their behavior.
        #
        lappend config package_id [ad_conn package_id]

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
