function main() {
    var sayHello = function() {
        window.alert("Hi!");
    }

    document.getElementById('sample_text_id').onclick = sayHello;
}

function sayHello() {
  window.alert("Hello");
}
