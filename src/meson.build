libbricks_header_subdir = package_subdir / package_api_name
libbricks_header_dir = get_option('includedir') / libbricks_header_subdir

libbricks_public_headers = files([
  'bricks.h',
  'brk-bin.h',
  'brk-toolbar.h',
  'brk-toolbar-view.h',
  'brk-tab-bar.h',
  'brk-tab-view.h',
  'brk-easing.h',
])

libbricks_private_headers = files([
  'brk-gizmo-private.h',
  'brk-widget-utils-private.h',
  'brk-tab-bar-private.h',
  'brk-tab-box-private.h',
  'brk-tab-private.h',
  'brk-tab-view-private.h',
  'brk-animation-util.h',
  'brk-fading-label-private.h',
  'brk-timed-animation.h',
  'brk-animation-target.h',
  'brk-bidi-private.h',
])

libbricks_public_sources = files([
  'brk-animation.c',
  'brk-bin.c',
  'brk-toolbar.c',
  'brk-toolbar-view.c',
  'brk-tab-bar.c',
  'brk-tab-view.c',
  'brk-timed-animation.c',
  'brk-animation-target.c',
  'bricks.c',
  'brk-version.c',
])
libbricks_private_sources = files([
  'brk-gizmo.c',
  'brk-widget-utils.c',
  'brk-tab-box.c',
  'brk-tab.c',
  'brk-animation-util.c',
  'brk-easing.c',
  'brk-fading-label.c',
  'brk-bidi.c',
])

libbricks_generated_headers = []
libbricks_generated_sources = []

libbricks_resources = gnome.compile_resources(
  'brk-resources',
  './resources/bricks.gresources.xml',
  source_dir: 'resources',
  gresource_bundle: false,
  c_name: 'brk',
)
libbricks_generated_headers += [libbricks_resources[1]]
libbricks_generated_sources += [libbricks_resources[0]]

libbricks_public_enum_headers = [
  'brk-animation.h',
  'brk-animation-target.h',
  'brk-toolbar-view.h',
  'brk-tab-bar.h',
  'brk-tab-view.h',
  'brk-easing.h',
]
libbricks_public_enums = gnome.mkenums_simple(
  'brk-enums',
  sources: libbricks_public_enum_headers,
  body_prefix: '#include "config.h"',
  header_prefix: '''
#if !defined(_BRICKS_INSIDE) && !defined(BRICKS_COMPILATION)
#error "Only <bricks.h> can be included directly."
#endif
''',
  install_dir: libbricks_header_dir,
)
libbricks_generated_headers += [libbricks_public_enums[1]]
libbricks_generated_sources += [libbricks_public_enums[0]]

libbricks_marshalers = gnome.genmarshal(
  'brk-marshalers',
  sources: 'brk-marshalers.list',
  prefix: 'brk_marshal',
  valist_marshallers: true,
)
libbricks_generated_headers += [libbricks_marshalers[1]]
libbricks_generated_sources += [libbricks_marshalers[0]]

version_data = configuration_data()
version_data.set('BRK_MAJOR_VERSION', bricks_version_major)
version_data.set('BRK_MINOR_VERSION', bricks_version_minor)
version_data.set('BRK_MICRO_VERSION', bricks_version_micro)
version_data.set('BRK_VERSION', meson.project_version())
libbricks_version_h = configure_file(
  input: 'brk-version.h.in',
  output: 'brk-version.h',
  install_dir: libbricks_header_dir,
  configuration: version_data,
)
libbricks_generated_headers += [libbricks_version_h]

config_data = configuration_data()
config_data.set_quoted('G_LOG_DOMAIN', 'Bricks')
config_data.set_quoted('GETTEXT_PACKAGE', 'libbricks')
config_data.set_quoted('LOCALEDIR', get_option('prefix') / get_option('localedir'))
libbricks_config_h = configure_file(output: 'config.h', configuration: config_data)
libbricks_generated_headers += []

install_headers(libbricks_public_headers, subdir: libbricks_header_subdir)

libbricks_link_args =[]
libbricks_symbols_file = 'libbricks.syms'

libbricks_deps = [
  fribidi_dep,
  glib_dep,
  gtk_dep,
  math_dep,
]
libbricks_public_deps = [
  gio_dep,
  gtk_dep,
]

libbricks = library(
  'bricks-' + apiversion,
  libbricks_private_sources + libbricks_public_sources + libbricks_generated_headers + libbricks_generated_sources,
  soversion: soversion,
  dependencies: libbricks_deps,
  include_directories: include_directories('.'),
  install: true,
  install_dir: libdir,
)

if get_option('vapi') and not generate_gir
  error('API reference requires introspection.')
endif

if generate_gir
  libbricks_gir_extra_args = [
    '--c-include=bricks.h',
    '--quiet',
    '-DBRICKS_COMPILATION',
  ]

  libbricks_gir = gnome.generate_gir(
    libbricks,
    sources: libbricks_public_sources + libbricks_generated_headers + libbricks_generated_sources,
    nsversion: apiversion,
    namespace: 'Brk',
    export_packages: package_api_name,
    symbol_prefix: 'brk',
    identifier_prefix: 'Brk',
    link_with: libbricks,
    includes: ['Gio-2.0', 'Gtk-4.0'],
    install: true,
    install_dir_gir: girdir,
    install_dir_typelib: typelibdir,
    extra_args: libbricks_gir_extra_args,
  )

  if get_option('vapi')
    libbricks_vapi = gnome.generate_vapi(
      package_api_name,
      sources: libbricks_gir[0],
      packages: [ 'gio-2.0', 'gtk4' ],
      install: true,
      install_dir: vapidir,
      metadata_dirs: [ meson.current_source_dir() ],
    )
  endif
endif

libbricks_dep = declare_dependency(
  sources: libbricks_public_headers,
  dependencies: libbricks_public_deps,
  link_with: libbricks,
  include_directories: include_directories('.'),
)
