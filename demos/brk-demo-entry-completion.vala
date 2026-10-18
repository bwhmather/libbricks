/* Entry/Completion
 *
 * GtkEntryCompletion provides a mechanism for adding support for
 * completion in GtkEntry.
 */

private GLib.ListModel
create_completion_model() {
    return new Gtk.StringList({
        "bricks",
        "brush",
        "Brilliant",
        "Bristol rovers",
        "brine",
        "total",
        "totally",
        "toto",
        "tottery",
        "totterer",
        "Totten trust",
        "Tottenham hotspurs",
        "totipotent",
        "totipotency",
        "totemism",
        "totem pole",
        "Totara",
        "totalizer",
        "totalizator",
        "totalitarianism",
        "total parenteral nutrition",
        "total eclipse",
        "Totipresence",
        "Totipalmi",
        "zombie",
        "aæx",
        "aæy",
        "aæz",
        null
    });
}

class Brk.EntryCompletionDemo : Gtk.Application {
    public EntryCompletionDemo() {
        Object(application_id: "com.bwhmather.libbricks.DemoEntryCompletion" );
    }

    public override void activate() {
        var window = new Gtk.ApplicationWindow(this) {
            title = "Completion",
            resizable = false
        };

        var vbox = new Gtk.Box(VERTICAL, 12) {
            margin_start = 18,
            margin_end = 18,
            margin_top = 18,
            margin_bottom = 18
        };
        window.set_child(vbox);

        var label = new Gtk.Label(null);
        label.set_markup("Try writing <b>total</b> or <b>bricks</b> for example.");
        vbox.append(label);

        var entry = new Brk.Entry();
        entry.completion_model = create_completion_model();
        vbox.append(entry);

        //entry.update_relation(LABELLED_BY, label);
        //label.update_property(AUTOCOMPLETE, AUTOCOMPLETE_LIST);

        window.visible = true;
    }
}

public int
main(string[] args) {
    Brk.init();
    var app = new Brk.EntryCompletionDemo();
    return app.run(args);
}