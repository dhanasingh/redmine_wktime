// WkLocationSelector — cascading 3-level location dropdown
// Supports horizontal (filter bar) and vertical (detail form) layouts.
// Semantic UI aware: uses dropdown('refresh') and dropdown('set selected').
//
// Usage: called from _location_selector.html.erb via
//   WkLocationSelector.init('<instance_id>');

(function() {
  if (window.WkLocationSelector) return;

  window.WkLocationSelector = (function() {

    function log() {
      if (window.console) console.log.apply(console, ['[WkLoc]'].concat([].slice.call(arguments)));
    }

    function ready(fn) {
      if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', fn);
      else fn();
    }

    function getJSON(url, cb) {
      $.ajax({ url: url, type: 'GET', dataType: 'json',
        success: function(d) { cb(null, d || []); },
        error:   function(x) { cb(new Error('HTTP ' + x.status)); }
      });
    }

    function findNode(nodes, id) {
      var t = String(id || '');
      for (var i = 0; i < nodes.length; i++) {
        if (String(nodes[i].id) === t) return nodes[i];
        var f = findNode(nodes[i].children || [], t);
        if (f) return f;
      }
      return null;
    }

    function findChain(nodes, id) {
      var t = String(id || '');
      for (var i = 0; i < nodes.length; i++) {
        if (String(nodes[i].id) === t) return [nodes[i]];
        var c = findChain(nodes[i].children || [], t);
        if (c) return [nodes[i]].concat(c);
      }
      return null;
    }

    // Direct children of every top-level node (the Level 2 set across all roots).
    function secondLevel(tree) {
      var out = [];
      (tree || []).forEach(function(n) {
        (n.children || []).forEach(function(c) { out.push({ id: c.id, name: c.name }); });
      });
      return out;
    }

    // Deepest leaves PER zone: for each node in `nodes` (a zone root), only the
    // leaves at that zone's maximum depth. Mirrors WkLocation.final_location_ids,
    // so e.g. South Zone with Madurai -> Melur yields only Melur (Chennai hidden).
    function deepestLeaves(nodes) {
      var out = [];
      (nodes || []).forEach(function(root) {
        var best = -1, acc = [];
        (function walk(node, d) {
          var kids = node.children || [];
          if (!kids.length) {
            if (d > best) { best = d; acc = [{ id: node.id, name: node.name }]; }
            else if (d === best) { acc.push({ id: node.id, name: node.name }); }
          } else {
            kids.forEach(function(c) { walk(c, d + 1); });
          }
        })(root, 0);
        out = out.concat(acc);
      });
      return out;
    }

    // Rebuild <option> list and tell Semantic UI to re-read them
    function fillOptions(select, rows, blankLabel) {
      select.innerHTML = '';
      var blank = document.createElement('option');
      blank.value = ''; blank.textContent = blankLabel || '';
      select.appendChild(blank);
      (rows || []).forEach(function(r) {
        var o = document.createElement('option');
        o.value = String(r.id); o.textContent = r.name;
        select.appendChild(o);
      });
      var $drop = $(select).closest('.ui.dropdown');
      if ($drop.length && $.fn.dropdown) {
        $drop.dropdown('refresh');
      }
    }

    // Set value on native select AND sync Semantic UI display text
    function setVal(select, value) {
      var v = String(value || '');
      select.value = v;
      var $drop = $(select).closest('.ui.dropdown');
      if ($drop.length && $.fn.dropdown) {
        $drop.dropdown('set selected', v);
      }
    }

    function init(id) {
      var root = document.getElementById(id);
      if (!root || root.dataset.ready === 'true') return;
      root.dataset.ready = 'true';

      var valueField     = document.getElementById(id + '_value');
      var level1         = document.getElementById(id + '_level_1');
      var level2         = document.getElementById(id + '_level_2');
      var locationSelect = document.getElementById(id + '_location_select');
      var treeUrl        = root.dataset.treeUrl;
      var selectedId     = root.dataset.selectedId;
      var includeBlank   = root.dataset.includeBlank !== 'false';
      var autoSubmit     = root.dataset.autoSubmit === 'true';
      var treeCache      = null;
      var _restoring     = false;

      function submitIfNeeded() {
        if (!autoSubmit) return;
        var fid = root.dataset.formId;
        var form = fid ? document.getElementById(fid) : root.closest('form');
        if (form) form.submit();
      }

      function setHidden(value, submit) {
        valueField.value = value || '';
        if (submit) submitIfNeeded();
      }

      function loadTree(cb) {
        if (treeCache) { cb(treeCache); return; }
        getJSON(treeUrl, function(err, tree) {
          treeCache = err ? [] : tree;
          cb(treeCache);
        });
      }

      // Direct children of a tree node, as {id,name} option rows.
      function childRows(node) {
        return (node && node.children || []).map(function(c){ return { id: c.id, name: c.name }; });
      }

      // ── User change handlers ──────────────────────────────────────────────
      // All option lists are derived from the single cached location tree
      // (loadTree), so changing a level never makes another server round-trip.

      $(level1).on('change', function() {
        if (_restoring) return;
        log('level1 change', level1.value);
        setHidden(level1.value, false);
        fillOptions(level2, [], '');
        fillOptions(locationSelect, [], '');
        if (!level1.value) return;
        loadTree(function(tree) {
          var node = findNode(tree, level1.value);
          fillOptions(level2, childRows(node), '');
          fillOptions(locationSelect, node ? deepestLeaves([node]) : [], '');
        });
      });

      $(level2).on('change', function() {
        if (_restoring) return;
        log('level2 change', level2.value);
        setHidden(level2.value, false);
        fillOptions(locationSelect, [], '');
        if (!level2.value) return;
        loadTree(function(tree) {
          var node = findNode(tree, level2.value);
          var kids = node ? (node.children || []) : [];
          if (!kids.length) {
            setHidden(level2.value, true);          // level 2 is itself a leaf
          } else {
            fillOptions(locationSelect, deepestLeaves([node]), '');
            setHidden(level2.value, false);
          }
        });
      });

      $(locationSelect).on('change', function() {
        if (_restoring) return;
        log('location change', locationSelect.value);
        setHidden(locationSelect.value, true);
      });

      // ── Restore on page load ──────────────────────────────────────────────
      // Single round-trip: fetch the whole permitted tree once, then build and
      // restore all three dropdowns synchronously from it (no per-level AJAX).

      loadTree(function(tree) {
        fillOptions(level1, tree.map(function(n){ return { id: n.id, name: n.name }; }),
                    includeBlank ? '' : '');

        if (!selectedId) {
          // Nothing pre-selected: show all Level 2 nodes and all leaves so every
          // dropdown is populated; picking a higher level narrows the rest.
          fillOptions(level2, secondLevel(tree), '');
          fillOptions(locationSelect, deepestLeaves(tree), '');
          return;
        }

        var chain = findChain(tree, selectedId);
        if (!chain || !chain.length) { log('chain not found', selectedId); return; }
        log('restoring', chain.map(function(n){ return n.name; }).join(' > '));

        var level1Id = String(chain[0].id);
        var level2Id = chain[1] ? String(chain[1].id) : null;
        var locId    = chain.length > 2 ? String(selectedId) : null;

        _restoring = true;
        setVal(level1, level1Id);

        // Always populate the lower dropdowns from the selected branch so the
        // user can keep drilling, even when only Level 1 (or Level 2) is chosen.
        var l1node = findNode(tree, level1Id);
        fillOptions(level2, childRows(l1node), '');
        if (level2Id) setVal(level2, level2Id);

        var l2node = level2Id ? findNode(tree, level2Id) : null;
        var zone = l2node || l1node;
        fillOptions(locationSelect, zone ? deepestLeaves([zone]) : [], '');
        if (locId) setVal(locationSelect, locId);

        setHidden(selectedId, false);
        _restoring = false;
      });
    }

    return { ready: ready, init: init };
  })();

})();
