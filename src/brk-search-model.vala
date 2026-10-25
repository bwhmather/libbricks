/*
 * Copyright (c) 2026 Ben Mather <bwhmather@bwhmather.com>
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

public interface Brk.SearchModel : GLib.ListModel {
    public abstract string? search { get; set; }
}

public interface Brk.AsyncSearchModel : Brk.SearchModel {
    public abstract bool loading { get; }
}