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
		"extraCount",
	];

	static values = {
		memberPrice: Object,
		nonMemberPrice: Object,
		otherCost: Number,
	};

	// Base function called when form modified
	calculate() {
		const courseCost = this.isMember(this.childTarget)
			? this.calcCourseCost(true)
			: this.calcCourseCost(false);

		const optionCost = this.optCostTargets
			.filter((cost) => cost.classList.contains("registered"))
			.reduce((sum, option) => sum + Number.parseInt(option.innerHTML), 0);

		const adjustmentCost = this.calcAdjustments();

		// Count the number of options registered for
		const optCount = this.optRegsTargets.reduce(
			(sum, target) => sum + target.querySelectorAll(".registered").length,
			0,
		);
		this.optCountTarget.innerHTML = `オプション：${optCount.toString()}つ`;

		const registeredNodes = [...document.getElementById("reg_slots").children];
		// Count slots with an extra cost
		const extraCostNodes = registeredNodes.filter(
			(slot) => slot.dataset.modifier !== "0",
		);
		this.extraCountTarget.innerHTML = extraCostNodes.length.toString();
		// Get their total effect on the cost
		const extraCost = extraCostNodes.reduce((sum, node) => {
			return sum + Number.parseInt(node.dataset.modifier);
		}, 0);

		// Inner text set in the invoice controller if the time slot has a snack fee
		const snackCost = Number.parseInt(this.snackCountTarget.innerText) * 165;

		const finalCost =
			optionCost + courseCost + adjustmentCost + snackCost + extraCost;
		this.finalCostTarget.innerHTML = `合計（税込）: ${finalCost}円`;
		this.eventCostTarget.innerHTML = `サマースクール 2023の合計: ${(
			this.otherCostValue + finalCost
		)
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
		this.memberPrice = this.memberPriceValue;
		this.nonMemberPrice = this.nonMemberPriceValue;
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

	// Calculates course costs if kids are both members/not
	calcCourseCost(member) {
		const courses = member ? this.memberPrice : this.nonMemberPrice;
		const id = Number.parseInt(this.childTarget.children[0].innerHTML);

		const cost = this.slotRegsTargets.reduce((sum, target) => {
			const numRegs = target.querySelectorAll(`.child${id}`).length;
			const courseCost = this.bestCourses(numRegs, courses);
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

	// True if child is a member
	isMember(child) {
		const membership = child.querySelector(".membership").innerHTML;

		return membership === "Yes";
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
