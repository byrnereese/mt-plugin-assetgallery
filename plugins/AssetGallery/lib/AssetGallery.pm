package AssetGallery;

use strict;
use MT::Util qw( encode_url );
use File::Spec::Functions;
use Digest::SHA1 qw( sha1_base64 );

sub init_app {
    my $plugin = shift;
    my ($app) = @_;
    return if $app->id eq 'wizard';
    my $r = $plugin->registry;
    $r->{tags} = sub { load_tags( $app, $plugin ) };

}

sub load_customfield_type {
    my $customfield_type = {
        'asset_gallery' => {
            label      => 'Asset Gallery',
            field_html => sub {
                my $plugin = MT->component('AssetGallery');
                return $plugin->load_tmpl('asset-gallery.tmpl');
            },
            field_html_params => sub {
                my ( $key, $tmpl_key, $param ) = @_;
                my $max_height = 0;

                # my $max_width = 580;

                my @asset_loop;
                my @asset_ids = split ',', $param->{value};
                foreach my $id (@asset_ids) {
                    my $asset = MT->model('asset')->load($id) or next;

                    my $row = $asset->column_values;
                    $row->{url} =
                      $asset->url;    # this has to be called to calculate
                    $row->{asset_id} =
                      $asset->id;     # this has to be called to calculate
                    $row->{label}       = $asset->label;
                    $row->{description} = $asset->description;

                    if ( $asset->has_thumbnail ) {
                        my @thumbnail =
                          $asset->thumbnail_url( Width => 60, Square => "1" );
                        $row->{thumbnail_url} = $thumbnail[0];
                        $max_height = $thumbnail[2]
                          if $thumbnail[2] > $max_height;

                        $param->{has_thumbnail} = 1;
                    }

                    push @asset_loop, $row;
                }
                $param->{asset_loop} = \@asset_loop;

                # $param->{height_ratio} = 0.1 + ($max_height / $max_width);
                $param->{max_height} = $max_height;
                $param->{listing_id} = $param->{field_id} . '-listing';
                ( $param->{field_basename} ) =
                  ( $param->{field_id} =~ /^customfield_(.*)$/ );
            },
            options_field => q{
                <div class="textarea-wrapper">&#60;<__trans phrase="Site Root">&#62; / <input type="text" name="options" value="<mt:var name="options" escape="html">" id="options" class="half-width" /></div>
                <p class="hint"><__trans phrase="Please enter a full path to where files should be uploaded to. Applicable <a href="http://www.movabletype.org/documentation/appendices/archive-file-path-specifiers.html">file path specifiers</a> may be used."></p>
            },
            column_def => 'vclob',
            order      => 799,
            no_default => 1
        }
    };

    return $customfield_type;
}

sub load_tags {
    my $app = shift;
    my $cmpnt  = MT->component('commercial');
    my $fields = $cmpnt->{customfields};
    my $tags   = {};
    if ( $fields && @$fields ) {
        foreach my $field (@$fields) {
            my $tag = $field->tag;
            next unless $tag;
            if ( $field->type =~ m/asset_gallery/ ) {
                $tags->{block}->{ $tag . 'Assets' } = sub {
                    $_[0]->stash( 'field', $field );
                    &_hdlr_assets;
                };
                $tags->{function}->{ $tag . 'AssetCount' } = sub {
                    $_[0]->stash( 'field', $field );
                    &_hdlr_asset_count;
                };
            }
        }
    }
    return $tags;
}

sub xfrm_entry {
    my ( $cb, $app, $tmpl ) = @_;
    $$tmpl =~ s/(name="entry_form")/$1 enctype=\"multipart\/form-data\"/g;
}

sub CMSPostSave {
    my ( $cb, $app, $obj ) = @_;
    return unless $app->isa('MT::App');
    my $q = $app->param;
    my $multifields;
    foreach my $field ( $app->param ) {
        if ( my ( $parent, $aid ) =
            ( $field =~ m/^asset_([^_]*)_(\d+)_label$/ ) )
        {
            $multifields->{ 'customfield_' . $parent } = 1;
            my $asset = MT->model('asset')->load($aid);
            next unless $asset;
            my $base = 'asset_' . $parent . '_' . $aid;
            $asset->label( $app->param( $base . '_label' ) );
            $asset->description( $app->param( $base . '_description' ) );
            $app->{'query'}->delete( $base . '_label' );
            $app->{'query'}->delete( $base . '_description' );
            $asset->save;
        }
        if ( my ( $parent, $i ) =
            ( $field =~ m/^customfield_(.*?)_multifile_(.*?)$/ ) )
        {
            $multifields->{ 'customfield_' . $parent } = 1;
            my @assets = split( ",", $app->param( 'customfield_' . $parent ) );
            unless ( $q->param($field) ) {
                $app->{'query'}->delete($field)
                  ;    # remove so others don't process it
                next;
            }
            my ( $asset, $bytes ) = _upload_file( $app, $obj, $field, $parent );
            $app->{'query'}->delete($field); # remove so others don't process it
            next if !defined $asset;
            push @assets, $asset->id;
            $app->param( 'customfield_' . $parent, join( ',', @assets ) );

#	    MT->log({ message => "app->param(".'customfield_'.$parent.") = " . $app->param('customfield_'.$parent) });
        }
    }

    #    clean up
    foreach my $f ( keys %$multifields ) {
        my @assets;
        foreach my $id ( split( ',', $app->param($f) ) ) {
            if ( MT->model('asset')->load($id) ) {
                push @assets, $id if ( MT->model('asset')->load($id) );
            }
        }
        $app->param( $f, join( ',', @assets ) );

        #	MT->log({ message => "app->param($f) = " . $app->param($f) });
    }
    $obj->save if $multifields;
    return 1;
}

## Mostly copied from MT::App::CMS::Asset::_upload_file
## we have to make it more re-usable!!
sub _upload_file {
    my ( $app, $obj, $field_name, $field_id ) = @_;

    my $q = $app->param;

    my $blog      = $app->blog;
    my $blog_id   = $blog->id;
    my $fmgr      = $blog->file_mgr;
    my $root_path = $blog->site_path;
    my $obj_type  = $obj->class_type || $obj->datasource;

    my ( $fh, $info ) = $app->upload_info($field_name);

    my $mimetype;
    $mimetype = $info->{'Content-Type'} if ($info);

    # eval { $fh = $q->upload($field_name) };
    #           if ($@ && $@ =~ /^Undefined subroutine/) {
    #              $fh = $q->param($field_name);
    #           }

    my $basename = $app->param($field_name);
    $basename =~ s!\\!/!g;    ## Change backslashes to forward slashes
    $basename =~ s!^.*/!!;    ## Get rid of full directory paths

    my $relative_path;

    require CustomFields::Field;
    my $field = CustomFields::Field->load(
        {
            $blog_id ? ( blog_id => [ $blog_id, 0 ] ) : ( blog_id => $blog_id ),
            basename => $field_id,
        }
    );
    my $file_tmpl = $field->options;

    if ( $file_tmpl =~ m/\%[_-]?[A-Za-z]/ ) {
        if ( $file_tmpl =~ m/<\$?MT/i ) {
            $file_tmpl =~
s!(<\$?MT[^>]+?>)|(%[_-]?[A-Za-z])!$1 ? $1 : '<mt:FileTemplate format="'. $2 . '">'!gie;
        }
        else {
            $file_tmpl = qq{<mt:FileTemplate format="$file_tmpl">};
        }
    }

    require MT::Template::Context;
    my $ctx = MT::Template::Context->new;
    $ctx->{current_timestamp} = $obj->created_on;
    local $ctx->{__stash}{$obj_type} = $obj;
    local $ctx->{__stash}{blog} = $blog;
    local $ctx->{__stash}{archive_category} = $obj if $obj_type eq 'category';
    local $ctx->{__stash}{author} =
      $obj_type eq 'entry' ? $obj->author : $app->user;

    require MT::Builder;
    my $build = MT::Builder->new;
    my $tokens = $build->compile( $ctx, $file_tmpl )
      or return $blog->error( $build->errstr() );
    unless ( $relative_path = $build->build( $ctx, $tokens ) ) {
        MT->log(
            { message => "error building $file_tmpl: " . $build->errstr() } );
        return $blog->error( $build->errstr() );
    }

    #my $path = File::Spec->catdir( $root_path, $relative_path );
    my $path;

    my $digest = sha1_base64($fh);
    $digest =~ s{[/+]}{}g;
    $digest =~ s{(.......)}{$1,}g;
    my @dirs = split( /,/, $digest );
    $path = File::Spec->catdir( $root_path, $relative_path, @dirs );

#    MT->log({ message => "digest: $digest, some path: $somepath, split: " . join(',',@dirs) });

    unless ( $fmgr->exists($path) ) {
        $fmgr->mkpath($path)
          or return $app->error(
            $app->translate(
                "Can't make path '[_1]': [_2]",
                $path, $fmgr->errstr
            )
          );
    }

    my $relative_url =
      File::Spec->catfile( $relative_path, @dirs, encode_url($basename) );
    $relative_path =
      $relative_path
      ? File::Spec->catfile( $relative_path, @dirs, $basename )
      : $basename;
    my $asset_file = $q->param('site_path') ? '%r' : '%a';
    $asset_file = File::Spec->catfile( $asset_file, $relative_path );
    my $local_file = File::Spec->catfile( $path, $basename );

    my $base_url =
        $app->param('site_path')
      ? $blog->site_url
      : $blog->archive_url;
    my $asset_base_url = $app->param('site_path') ? '%r' : '%a';

    ## Untaint. We have already tested $basename and $relative_path for security
    ## issues above, and we have to assume that we can trust the user's
    ## Local Archive Path setting. So we should be safe.
    ($local_file) = $local_file =~ /(.+)/s;

    require MT::Image;
    my ( $w, $h, $id, $write_file ) = MT::Image->check_upload(
        Fh    => $fh,
        Fmgr  => $fmgr,
        Local => $local_file
    );

    return $app->error( MT::Image->errstr )
      unless $write_file;

    ## File does not exist, or else we have confirmed that we can overwrite.
    my $umask = oct $app->config('UploadUmask');
    my $old   = umask($umask);
    defined( my $bytes = $write_file->() )
      or return $app->error(
        $app->translate(
            "Error writing upload to '[_1]': [_2]", $local_file,
            $fmgr->errstr
        )
      );
    umask($old);

    ## Close up the filehandle.
    close $fh;

    ## We are going to use $relative_path as the filename and as the url passed
    ## in to the templates. So, we want to replace all of the '\' characters
    ## with '/' characters so that it won't look like backslashed characters.
    ## Also, get rid of a slash at the front, if present.
    $relative_path =~ s!\\!/!g;
    $relative_path =~ s!^/!!;
    $relative_url  =~ s!\\!/!g;
    $relative_url  =~ s!^/!!;
    my $url = $base_url;
    $url .= '/' unless $url =~ m!/$!;
    $url .= $relative_url;
    my $asset_url = $asset_base_url . '/' . $relative_url;

    require File::Basename;
    my $local_basename = File::Basename::basename($local_file);
    my $ext =
      ( File::Basename::fileparse( $local_file, qr/[A-Za-z0-9]+$/ ) )[2];

    my $asset_pkg = MT->model('asset')->handler_for_file($local_basename);
    my $is_image =
         defined($w)
      && defined($h)
      && $asset_pkg->isa('MT::Asset::Image');
    my $asset;
    if (
        !(
            $asset = $asset_pkg->load(
                { file_path => $asset_file, blog_id => $blog_id }
            )
        )
      )
    {
        $asset = $asset_pkg->new();
        $asset->file_path($asset_file);
        $asset->file_name($local_basename);
        $asset->file_ext($ext);
        $asset->blog_id($blog_id);
        $asset->created_by( $app->user->id );
    }
    else {
        $asset->modified_by( $app->user->id );
    }

    my $original = $asset->clone;
    $asset->url($asset_url);
    if ($is_image) {
        $asset->image_width($w);
        $asset->image_height($h);
    }
    $asset->mime_type($mimetype) if $mimetype;
    $asset->save;
    $app->run_callbacks( 'cms_post_save.asset', $app, $asset, $original );

    if ($is_image) {
        $app->run_callbacks(
            'cms_upload_file.' . $asset->class,
            File  => $local_file,
            file  => $local_file,
            Url   => $url,
            url   => $url,
            Size  => $bytes,
            size  => $bytes,
            Asset => $asset,
            asset => $asset,
            Type  => 'image',
            type  => 'image',
            Blog  => $blog,
            blog  => $blog
        );
        $app->run_callbacks(
            'cms_upload_image',
            File       => $local_file,
            file       => $local_file,
            Url        => $url,
            url        => $url,
            Size       => $bytes,
            size       => $bytes,
            Asset      => $asset,
            asset      => $asset,
            Height     => $h,
            height     => $h,
            Width      => $w,
            width      => $w,
            Type       => 'image',
            type       => 'image',
            ImageType  => $id,
            image_type => $id,
            Blog       => $blog,
            blog       => $blog
        );
    }
    else {
        $app->run_callbacks(
            'cms_upload_file.' . $asset->class,
            File  => $local_file,
            file  => $local_file,
            Url   => $url,
            url   => $url,
            Size  => $bytes,
            size  => $bytes,
            Asset => $asset,
            asset => $asset,
            Type  => 'file',
            type  => 'file',
            Blog  => $blog,
            blog  => $blog
        );
    }

    return ( $asset, $bytes );
}

sub _hdlr_asset_count {
    my ( $ctx, $args, $cond ) = @_;
    require CustomFields::Template::ContextHandlers;
    my $plugin = MT->component("AssetGallery");
    my $value =
      CustomFields::Template::ContextHandlers::_hdlr_customfield_value( $ctx,
        $args );

    return 0 unless $value;
    my @asset_ids = split( /,/, $value );
    my $count = $#asset_ids + 1;
    return $ctx->count_format( $count, $args );
}

sub _hdlr_assets {
    my $plugin = MT->component("AssetGallery");
    my ( $ctx, $args, $cond ) = @_;

    my $tokens  = $ctx->stash('tokens');
    my $builder = $ctx->stash('builder');
    my $res     = '';

    require CustomFields::Template::ContextHandlers;
    my $value =
      CustomFields::Template::ContextHandlers::_hdlr_customfield_value( $ctx,
        $args );

    return '' unless $value;

    my @asset_ids   = split( /,/, $value );
    my $count       = 0;
    my $asset_count = 0;
    my $vars        = $ctx->{__stash}{vars} ||= {};
    my $lastn       = $args->{lastn};

    foreach my $id (@asset_ids) {
        $count++;

        my $asset = MT->model('asset')->load($id);
        next unless $asset;

        $asset_count++;
        last if $lastn && $asset_count > $lastn;

        local $ctx->{__stash}{asset} = $asset;
        local $vars->{__first__}     = $asset_count == 1;
        local $vars->{__last__}      = !defined $asset_ids[$count];
        local $vars->{__odd__}       = ( $asset_count % 2 ) == 1;
        local $vars->{__even__}      = ( $asset_count % 2 ) == 0;
        local $vars->{__counter__}   = $asset_count;
        defined( my $out = $builder->build( $ctx, $tokens ) )
          or return $ctx->error( $builder->errstr );
        $res .= $out;
    }

    $res;
}

1;
