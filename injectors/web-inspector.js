(function() {
    let inspectorEnabled = false;
    let styleElement = null;
    const buttons = [];

    function generateSelector(element) {
        if (element.id) {
            return '#' + element.id;
        }
        let selector = element.tagName.toLowerCase();
        if (element.className) {
            selector += '.' + element.className.trim().replace(/\s+/g, '.');
        }
        return selector;
    }

    function enableInspector() {
        if (inspectorEnabled) return;
        inspectorEnabled = true;

        styleElement = document.createElement('style');
        styleElement.textContent = '\
        .buildflowz-outline {\
            outline: 1px solid #FF0000;\
            position: relative;\
        }\
        .buildflowz-button {\
            position: absolute;\
            top: 0;\
            left: 50%;\
            transform: translate(-50%, -100%);\
            background: #FF0000;\
            color: white;\
            padding: 2px 5px;\
            font-size: 10px;\
            border: none;\
            border-radius: 3px;\
            z-index: 9999;\
        }\
        #buildflowz-inspector-toggle {\
            position: fixed;\
            top: 10px;\
            right: 10px;\
            z-index: 10000;\
            background: #333;\
            color: #fff;\
            border-radius: 50%;\
            width: 40px;\
            height: 40px;\
            font-size: 20px;\
            cursor: pointer;\
            box-shadow: 0 2px 5px rgba(0,0,0,0.3);\
        }\
        @media (max-width: 768px) {\
            .buildflowz-outline {\
                outline: 1px solid #FF0000;\
            }\
            .buildflowz-button {\
                padding: 3px 6px;\
                font-size: 11px;\
            }\
            #buildflowz-inspector-toggle {\
                width: 50px;\
                height: 50px;\
                font-size: 24px;\
            }\
        }';
        document.head.appendChild(styleElement);

        var divs = document.querySelectorAll('div');
        divs.forEach(function(div, index) {
            div.classList.add('buildflowz-outline');

            var button = document.createElement('button');
            button.textContent = index + 1;
            button.classList.add('buildflowz-button');
            div.appendChild(button);
            buttons.push(button);

            button.addEventListener('click', function(event) {
                event.stopPropagation();
                var selector = generateSelector(div);
                navigator.clipboard.writeText(selector).then(function() {
                    console.log('Selector copied: ', selector);
                });
            });
            button.addEventListener('touchend', function(event) {
                event.stopPropagation();
                var selector = generateSelector(div);
                navigator.clipboard.writeText(selector).then(function() {
                    console.log('Selector copied: ', selector);
                });
            });
        });
    }

    function disableInspector() {
        if (!inspectorEnabled) return;

        if (styleElement && styleElement.parentNode === document.head) {
            document.head.removeChild(styleElement);
        }

        buttons.forEach(function(button) {
            if (button.parentNode) {
                button.parentNode.removeChild(button);
            }
        });
        buttons.length = 0;

        document.querySelectorAll('.buildflowz-outline').forEach(function(div) {
            div.classList.remove('buildflowz-outline');
        });

        inspectorEnabled = false;
    }

    function toggleInspector() {
        if (inspectorEnabled) {
            disableInspector();
        } else {
            enableInspector();
        }
    }

    function initToggleButton() {
        var toggleButton = document.createElement('button');
        toggleButton.id = 'buildflowz-inspector-toggle';
        toggleButton.textContent = '\uD83D\uDD0D';
        toggleButton.title = 'Toggle Web Inspector';
        toggleButton.style.cssText = 'position:fixed;top:10px;right:10px;z-index:10000;background:#333;color:#fff;border:none;border-radius:50%;width:40px;height:40px;font-size:20px;cursor:pointer;box-shadow:0 2px 5px rgba(0,0,0,0.3);';
        toggleButton.addEventListener('click', toggleInspector);
        document.body.appendChild(toggleButton);
    }

    if (!window.__buildflowzInspectorLoaded) {
        window.__buildflowzInspectorLoaded = true;
        document.body.style.backgroundColor = 'lightyellow';
        initToggleButton();
    }
})();