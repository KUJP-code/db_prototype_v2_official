import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
	static targets = [
		"adjChange",
		"child",
		"confirm",
		"eventCost",
		"finalCost",
		"optRegs",
		"optCost",
		"optCount",
		"slotRegs",
		"snackCount",
	];

	static values = {
		eventName: String,
		priceList: Object,
		siblingEventCost: Number,
		snackCost: Number,
	};

	// Base function called when form modified
	calculate() {
		const courseCost = this.calcCourseCost();
		const optionCost = this.optCostTargets
			.filter((cost) => cost.classList.contains("registered"))
			.reduce((sum, option) => sum + Number.parseInt(option.innerHTML), 0);

		// Apply adjustments, scaling early bird per child regs
		let adjustmentCost = this.calcAdjustments();
		if (this.hasAdjChangeTarget) {
			const adjTexts = this.adjChangeTargets.map((n) => n.textContent.trim());
			if (adjTexts.length === 1) {
				const singleAdj = Number.parseInt(adjTexts[0].replace(/[^\d-]/g, ""), 10);
				if (singleAdj < 0) {
					const currentChildId = Number.parseInt(this.childTarget.children[0].innerHTML, 10);
					const regCountForChild = this.slotRegsTargets.reduce((sum, target) => {
						return sum + target.querySelectorAll(`.child${currentChildId}`).length;
					}, 0);
					adjustmentCost = singleAdj * regCountForChild;
				}
			}
		}

		const optCount = this.optRegsTargets.reduce(
			(sum, target) => sum + target.querySelectorAll(".registered").length,
			0,
		);
		this.optCountTarget.innerHTML = `オプション：${optCount}つ`;

		const registeredNodes = [...document.getElementById("reg-slots").children];
		const extraCost = registeredNodes.reduce(
			(sum, node) => sum + Number.parseInt(node.dataset.modifier || "0"),
			0,
		);

		const snackCost = Number.parseInt(this.snackCountTarget.innerText) * this.snackCostValue;

		let finalCost = optionCost + courseCost + adjustmentCost + snackCost + extraCost;
		if (finalCost < 0) finalCost = 0;

		this.finalCostTarget.innerHTML =
			`合計（税込）: ${finalCost.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",")}円`;

		this.eventCostTarget.innerHTML =
			`${this.eventNameValue}の合計: ${(this.siblingEventCostValue + finalCost)
				.toString()
				.replace(/\B(?=(\d{3})+(?!\d))/g, ",")}円`;

		this.allowSubmission();
	}


	// Finds the cheapest price for the given number of regs
	bestCourses(numRegs, courses) {
		if (numRegs === 0) return 0;
		if (numRegs < 3) return this.spotUse(numRegs, courses);

		const course = this.nextLowestCourse(numRegs);
		const cost = courses[course];

		if (cost === null) return this.handleMissingCourse(numRegs, courses);

		return cost + this.bestCourses(numRegs - course, courses);
	}

	// Get the course objects on connect so you don't have to parse before each calculation
	connect() {
		this.confirmText = this.confirmTarget.value;
		this.initialCost = this.getInitialCost();
		this.priceList = this.priceListValue;
		this.preventSubmission();
	}

	// Calculates total change due to adjustments
	calcAdjustments() {
		return this.hasAdjChangeTarget
			? this.adjChangeTargets.reduce(
				(sum, change) =>
					sum +
					Number.parseInt(
						change.innerHTML.replace(",", "").replace("円", ""),
					),
				0,
			)
			: 0;
	}

	calcCourseCost() {
		const id = Number.parseInt(this.childTarget.children[0].innerHTML);

		const cost = this.slotRegsTargets.reduce((sum, target) => {
			const numRegs = target.querySelectorAll(`.child${id}`).length;
			const courseCost = this.bestCourses(numRegs, this.priceList);
			return sum + courseCost;
		}, 0);

		return cost;
	}

	// Calculates cost from spot use when less than 5 courses
	spotUse(numRegs, courses) {
		return courses[1] * numRegs;
	}

	handleMissingCourse(numRegs, courses) {
		if (numRegs > 6) {
			return (
				this.bestCourses(numRegs - 5, courses) + this.bestCourses(5, courses)
			);
		}
		if (numRegs > 3) {
			return (
				this.bestCourses(numRegs - 3, courses) + this.bestCourses(3, courses)
			);
		}

		return this.spotUse(numRegs, courses);
	}

	// Find the largest course that fits the number of registrations
	nextLowestCourse(num) {
		// 50 is the largest possible course
		if (num > 55) return 50;
		// 3 is the smallest possible course (other than spot)
		if (num < 5 && num >= 3) return 3;

		return Math.floor(num / 5) * 5;
	}

	getInitialCost() {
		return Number.parseInt(this.finalCostTarget.innerHTML.replace(/\D/g, ""));
	}

	allowSubmission() {
		this.confirmTarget.disabled = false;
		this.confirmTarget.value = this.confirmText;
	}

	preventSubmission() {
		this.confirmTarget.disabled = true;
		this.confirmTarget.value = "お申込み(*要選択)";
	}
}
