$(document).ready(function(){
	let t;
	let msSinceClick;
	let timerState = "off";
	let timerOn = $('#totalhours').attr("timer-on");
	let totalhours = $('#totalhours').attr("totalhours")
	let totalTimeMs = Number(totalhours)*1000;
	// checkClockState;
	let clockState = setInterval(checkClockState, 5000)

	if (timerOn === 'true') {
		msSinceClick = new Date().getTime();
		clockIn();
	}

	$('#clockin').click(function(){
		msSinceClick = new Date().getTime();
		clockIn();
	});

	$('#clockout').click(function(){
		clearTimeout(t);
	})

	function clockIn() {
		let now = new Date();
		let nowInMs = now.getTime();

		let currentTimeInMs = (nowInMs - msSinceClick) + totalTimeMs;
		let currentDate = milisToTimestamp(currentTimeInMs);

		$('#totalhours').text(`${currentDate}`);
		timerState = "on";
	    t = setTimeout(clockIn, 1000);
	    if (document.getElementById('clockin').style.display === "block") {
			timerState = "off";
			clearTimeout(t);
		}
	}

	function validateTime(value) {
		if (value < 10) {
			value = "0" + value;
		}
		return value;
	}

	function milisToTimestamp(milis) {
		let currentDate = new Date (milis);
		let h = currentDate.getUTCHours();
		let m = currentDate.getUTCMinutes();
		let s = currentDate.getUTCSeconds();

		h = validateTime(h);
		m = validateTime(m);
		s = validateTime(s);

		return `${h}:${m}:${s}`;
	}

	function checkClockState(){
		if (document.getElementById('clockout').style.display === "block" && timerState === "off") {
			msSinceClick = new Date().getTime();
			clockIn();
		}

	}
});
