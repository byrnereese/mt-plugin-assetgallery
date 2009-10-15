# Asset Gallery - A plugin for Movable Type
# Copyright (c) 2008, Six Apart

package MT::Plugin::AssetGallery;

use strict;
use MT 4.0;
use base qw( MT::Plugin );

# Define $DISPLAY_NAME only if different from package ending (i.e. TestPlugin)
our $DISPLAY_NAME = 'Asset Gallery'; 
our $VERSION = '1.0'; 

our ($plugin, $PLUGIN_MODULE, $PLUGIN_KEY);
MT->add_plugin($plugin = __PACKAGE__->new({
   id          => plugin_module(),
   key         => plugin_key(),
   name        => plugin_name(),
   description => "Introduces a new custom field that allows you to create a gallery of assets",
   version     => $VERSION,
   author_name => "Six Apart",
   author_link => "http://sixapart.com/",
   # plugin_link => "http://plugins.movalog.com/asset-gallery/",
}));

sub init_registry {
    my $plugin = shift;
    $plugin->registry({
        customfield_types => '$AssetGallery::AssetGallery::load_customfield_type',
        callbacks => {
            'api_post_save.entry' => { # For MTCS
                handler => '$AssetGallery::AssetGallery::CMSPostSave',
                priority => 2
            },
            'cms_post_save.entry' => {
                handler => '$AssetGallery::AssetGallery::CMSPostSave',
                priority => 2
            },
            'MT::App::CMS::template_source.edit_entry' => sub {
                my ($cb, $app, $tmpl) = @_;
                
                $$tmpl =~ s/(name="entry_form")/$1 enctype=\"multipart\/form-data\"/g;
            },
            'cms_post_save.page' => {
                handler => '$AssetGallery::AssetGallery::CMSPostSave',
                priority => 2
            },
            'cms_post_save.category' => {
                handler => '$AssetGallery::AssetGallery::CMSPostSave',
                priority => 2
            },
            'cms_post_save.folder' => {
                handler => '$AssetGallery::AssetGallery::CMSPostSave',
                priority => 2
            },
            'cms_post_save.author' => {
                handler => '$AssetGallery::AssetGallery::CMSPostSave',
                priority => 2
            }
        },
        tags => '$AssetGallery::AssetGallery::load_tags'
    });
}

sub plugin_name     { return ($DISPLAY_NAME || plugin_module()) }
sub plugin_module   {
    $PLUGIN_MODULE or ($PLUGIN_MODULE = __PACKAGE__) =~ s/^MT::Plugin:://;
    return $PLUGIN_MODULE;
}
sub plugin_key      {
    $PLUGIN_KEY or ($PLUGIN_KEY = lc(plugin_module())) =~ s/\s+//g;
    return $PLUGIN_KEY
}

sub instance { return $plugin; }

1;