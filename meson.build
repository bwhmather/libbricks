project(
  'libbricks', 'vala',
  version: '1.0.alpha',
  license: 'LGPL-2.1-or-later',
  meson_version: '>= 1.3.0',
)

gnome = import('gnome')
pkgconfig = import('pkgconfig')

cc = meson.get_compiler('c')

version_arr = meson.project_version().split('-')[0].split('.')
bricks_version_major = version_arr[0].to_int()
bricks_version_minor = version_arr[1].to_int()
if version_arr[2].startswith('alpha') or version_arr[2].startswith('beta') or version_arr[2].startswith('rc')
  bricks_version_micro = 0
else
  bricks_version_micro = version_arr[2].to_int()
endif

apiversion = bricks_version_major.to_string()
package_api_name = '@0@-@1@'.format(meson.project_name(), apiversion)

soversion = bricks_version_minor.to_string()

package_subdir = get_option('package_subdir') # When used as subproject
if package_subdir != ''
  datadir = get_option('datadir') / package_subdir
  libdir = get_option('libdir') / package_subdir
  girdir = get_option('datadir') / package_subdir / 'gir-1.0'
  typelibdir = get_option('libdir') / package_subdir / 'girepository-1.0'
  vapidir = get_option('datadir') / package_subdir / 'vapi'
else
  datadir = get_option('datadir')
  libdir = get_option('libdir')
  girdir = get_option('datadir') / 'gir-1.0'
  typelibdir = get_option('libdir') / 'girepository-1.0'
  vapidir = get_option('datadir') / 'vala' / 'vapi'
endif

add_project_arguments(
  '--gresourcesdir', 'resources',
  '--gresources', meson.current_source_dir() / 'src/resources/bricks.gresources.xml',
  '--vapidir=' + meson.source_root() + '/vapi/',
  '--pkg', 'config',
  language: 'vala'
)

add_project_arguments([
  '-include', 'config.h',
  '-Wno-pedantic',
  '-Wno-discarded-qualifiers',
  '-Wno-unused-but-set-variable',
  '-Wno-unused-function',
  '-Wno-unused-parameter',
  '-Wno-unused-variable',
], language: 'c')

glib_dep = dependency('glib-2.0')
gio_dep = dependency('gio-2.0')
gtk_dep = dependency('gtk4', include_type: 'system')
math_dep = cc.find_library('m')

libbricks_deps = [
  math_dep,
  glib_dep,
  gio_dep,
  gtk_dep,
]

libbricks_public_deps = [
  glib_dep,
  gio_dep,
  gtk_dep,
]

libbricks_sources = [
  'src/brk-main.vala',
  'src/brk-button-group.vala',
  'src/brk-statusbar.vala',
  'src/brk-tab-view.vala',
  'src/brk-toolbar-view.vala',
  'src/brk-toolbar.vala',
  #  'src/brk-style-manager.vala',
]

libbricks_header_subdir = package_subdir / package_api_name
libbricks_header_dir = get_option('includedir') / libbricks_header_subdir

config_data = configuration_data()
config_data.set_quoted('G_LOG_DOMAIN', 'Bricks')
config_data.set_quoted('GETTEXT_PACKAGE', 'libbricks')
config_data.set_quoted('LOCALEDIR', get_option('prefix') / get_option('localedir'))
config_data.set_quoted('BRK_DATA_PREFIX', get_option('prefix'))
libbricks_config_h = configure_file(output: 'config.h', configuration: config_data)

libbricks = shared_library(
  'bricks-' + apiversion,
  libbricks_sources,
  vala_header: package_api_name / 'bricks.h',
  vala_gir: 'Brk-@0@.@1@.gir'.format(bricks_version_major, bricks_version_minor),
  soversion: soversion,
  dependencies: libbricks_deps,
  include_directories: libbricks_header_subdir,
  install: true,
  install_dir: libdir,
)

libbricks_dep = declare_dependency(
  dependencies: libbricks_public_deps,
  link_with: libbricks,
)

if not meson.is_subproject()
    subdir('docs')
endif
