test_suites = {
  'lint': [
    'exact-includes',
    'entrypoint',
    'no-circular-includes',
    'source-and-header-contents-match',
    'source-and-header-orders-match',
    'unused-symbols',
  ],
}

pymod = import('python')
python = pymod.find_installation('python3')

foreach suite, tests : test_suites
  foreach test_name : tests
    test(
      suite + '-' + test_name,
      python,
      args: [
        meson.current_source_dir() +
        '/' + suite +
        '/test_' + test_name.replace('-', '_') + '.py',
      ],
      env: {
        'MESON_BUILD_ROOT': meson.project_build_root(),
        'MESON_SOURCE_ROOT': meson.project_source_root(),
      },
      timeout: 1000,
    )
  endforeach
endforeach
