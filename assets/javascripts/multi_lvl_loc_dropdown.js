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

    function withParent(url, parentId) {
      return url + (url.indexOf('?') === -1 ? '?' : '&') + 'parent_id=' + encodeURIComponent(parentId || '');
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

    function leafRows(nodes, out) {
      out = out || [];
      (nodes || []).forEach(function(n) {
        if (n.children && n.children.length) leafRows(n.children, out);
        else out.push({ id: n.id, name: n.name });
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
      var childrenUrl    = root.dataset.childrenUrl;
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

      // ── User change handlers ──────────────────────────────────────────────

      $(level1).on('change', function() {
        if (_restoring) return;
        log('level1 change', level1.value);
        setHidden(level1.value, false);
        fillOptions(level2, [], '');
        fillOptions(locationSelect, [], '');
        if (!level1.value) return;
        getJSON(withParent(childrenUrl, level1.value), function(err, rows) {
          fillOptions(level2, err ? [] : rows, '');
          setHidden(level1.value, false);
        });
      });

      $(level2).on('change', function() {
        if (_restoring) return;
        log('level2 change', level2.value);
        setHidden(level2.value, false);
        fillOptions(locationSelect, [], '');
        if (!level2.value) return;
        getJSON(withParent(childrenUrl, level2.value), function(err, children) {
          children = err ? [] : children;
          if (!children.length) {
            setHidden(level2.value, true);
          } else {
            loadTree(function(tree) {
              var parent = findNode(tree, level2.value);
              fillOptions(locationSelect, parent ? leafRows(parent.children || []) : [], '');
              setHidden(level2.value, false);
            });
          }
        });
      });

      $(locationSelect).on('change', function() {
        if (_restoring) return;
        log('location change', locationSelect.value);
        setHidden(locationSelect.value, true);
      });

      // ── Restore on page load ──────────────────────────────────────────────
      // Sequential: roots → level1 → level2 children → location children
      // Uses setVal() which syncs both native select and Semantic UI display

      getJSON(withParent(childrenUrl, ''), function(err, roots) {
        var rootRows = err ? [] : roots;
        fillOptions(level1, rootRows, includeBlank ? '' : '');

        if (!selectedId) return;

        loadTree(function(tree) {
          var chain = findChain(tree, selectedId);
          if (!chain || !chain.length) { log('chain not found', selectedId); return; }
          log('restoring', chain.map(function(n){ return n.name; }).join(' > '));

          // Resolve level1Id — must be one of the loaded roots
          var rootIds = rootRows.map(function(r){ return String(r.id); });
          var level1Id = null;
          if (rootIds.indexOf(String(chain[0].id)) !== -1) {
            level1Id = String(chain[0].id);
          } else {
            for (var i = 0; i < rootRows.length; i++) {
              var rn = findNode(tree, rootRows[i].id);
              if (rn && findNode(rn.children || [], chain[0].id)) {
                level1Id = String(rootRows[i].id);
                chain = findChain([rn], selectedId) || chain;
                break;
              }
            }
          }
          if (!level1Id) { log('no root found', selectedId); return; }

          var level2Id = chain[1] ? String(chain[1].id) : null;
          var locId    = chain.length > 2 ? String(selectedId) : null;

          _restoring = true;

          // Step 1: restore level1
          setVal(level1, level1Id);
          log('level1 restored:', level1.value);

          if (!level2Id) {
            setHidden(level1Id, false);
            _restoring = false;
            return;
          }

          // Step 2: load level2 options then restore level2
          getJSON(withParent(childrenUrl, level1Id), function(err, l2rows) {
            fillOptions(level2, err ? [] : l2rows, '');
            setVal(level2, level2Id);
            log('level2 restored:', level2.value);
            setHidden(level2Id, false);

            if (!locId) { _restoring = false; return; }

            // Step 3: load location options then restore location
            loadTree(function(tree2) {
              var parent = findNode(tree2, level2Id);
              var locs = parent ? leafRows(parent.children || []) : [];
              fillOptions(locationSelect, locs, '');
              setVal(locationSelect, locId);
              log('location restored:', locationSelect.value);
              setHidden(locId, false);
              _restoring = false;
            });
          });
        });
      });
    }

    return { ready: ready, init: init };
  })();

})();
