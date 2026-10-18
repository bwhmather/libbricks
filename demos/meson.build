demos = [
    'brk-demo-entry-completion',
]

demo_deps = [
    libbricks_dep,
]

foreach demo : demos
    executable(
        demo,
        demo + '.vala',
        vala_args: ['--pkg', 'gtk4'],
        install: false,
        dependencies: demo_deps,
    )
endforeach