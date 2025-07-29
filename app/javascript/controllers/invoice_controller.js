import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
	static targets = [
		"slotTemplate",
		"slotTarget",
		"optTemplate",
		"optTarget",
		"snackCount",
		"merchTemplate",
	];

	add(child, cost, id, snack, type, modifier, name) {
		let wrapper;
		if (type === "TimeSlot") {
			wrapper = document.getElementById(`slot${id}child${child}`);
		} else if (type === "Option") {
			wrapper = document.getElementById(`opt${id}child${child}`);
		} else if (type === "MerchItem") {
			wrapper = document.getElementById(`merch${id}child${child}`);
		}

		if (wrapper) {
			// For existing registrations
			const destroy = wrapper.querySelector("input[name*='_destroy']");
			destroy.value = "0";
			wrapper.classList.add(`child${child}`);
			if (type === "Option") {
				const cost = wrapper.querySelector(".opt_cost.hidden");
				cost.classList.add("registered");
			}
		} else {
			// For newly created registrations
			if (type === "TimeSlot") {
				const content = this.slotTemplateTarget.innerHTML
					.replace(/REG_INDEX/g, new Date().getTime().toString())
					.replace(/NEW_ID/g, `slot${id}child${child}`)
					.replace(/NEW_CLASS/, `child${child}`)
					.replace(/NEW_CHILD_ID/g, child)
					.replace(/NEW_REGISTERABLE_ID/g, id);
				this.slotTargetTarget.insertAdjacentHTML("beforebegin", content);
			} else if (type === "Option") {
				const content = this.optTemplateTarget.innerHTML
					.replace(/REG_INDEX/g, new Date().getTime().toString())
					.replace(/NEW_ID/g, `opt${id}child${child}`)
					.replace(/NEW_CLASS/, `child${child}`)
					.replace(/NEW_CHILD_ID/g, child)
					.replace(/NEW_REGISTERABLE_ID/g, id)
					.replace(/NEW_COST/g, cost);
				this.optTargetTarget.insertAdjacentHTML("beforebegin", content);
			} else if (type === "MerchItem") {
				const content = this.merchTemplateTarget.innerHTML
					.replace(/REG_INDEX/g, new Date().getTime().toString())
					.replace(/NEW_CHILD_ID/g, child)
					.replace(/NEW_REGISTERABLE_ID/g, id)
					.replace(/NEW_COST/g, modifier);
					console.log("MERCH CONTENT", content);
				this.optTargetTarget.insertAdjacentHTML("beforebegin", content);

				const insertedId = `merch${id}child${child}`;
				const newNode = document.getElementById(insertedId);
				if (newNode) {
					const costNode = newNode.querySelector(".merch_cost");
					if (costNode) costNode.classList.add("registered");
				}
			}


		}

		if (type === "TimeSlot") {
			// Add the name of the registration to the registration list
			const nameContainer = document.getElementById("reg-slots");
			const nameP = document.createElement("p");
			nameP.dataset.modifier = modifier;
			nameP.innerText = name.replaceAll("_", " ");
			nameP.classList.add("hidden");
			nameContainer.appendChild(nameP);

			// Sort the registration list alphabetically
			const sortedActivities = [...nameContainer.children].sort((a, b) => {
				return a.innerText > b.innerText;
			});
			nameContainer.innerHTML = "";
			nameContainer.append(...sortedActivities);
		}

		if (snack === "true") {
			const snackCount = parseInt(this.snackCountTarget.innerText);
			this.snackCountTarget.innerText = (snackCount + 1).toString();
		}

		this.dispatch("add");
	}

	change(e) {
		const child = e.detail.child;
		const checked = e.detail.checked;
		const cost = e.detail.cost;
		const id = e.detail.id;
		const modifier = e.detail.modifier;
		const name = e.detail.name ? e.detail.name : null;
		const siblings = e.detail.siblings;
		const snack = e.detail.snack;
		const type = e.detail.type;

		if (checked && ["TimeSlot", "Option", "MerchItem"].includes(type)) {
			return this.add(child, cost, id, snack, type, modifier, name);
		
		} else if (checked && type === "Radio") {
			return this.radio(child, cost, id, siblings, name);
		} else {
			return this.remove(child, id, snack, type, name);
		}
	}

	radio(child, cost, id, siblings, name) {
		if (name !== "なし") {
			this.add(child, cost, id, false, "Option", 0, name);
		}

		siblings.forEach((sibling) => {
			const child = sibling.dataset.registerChildValue;
			const id = sibling.dataset.registerIdValue;

			this.remove(child, id, false, "Option", name);
		});
	}

	remove(child, id, snack, type, name) {
		let wrapper;
		if (type === "TimeSlot") {
			wrapper = document.getElementById(`slot${id}child${child}`);
		} else if (type === "Option") {
			wrapper = document.getElementById(`opt${id}child${child}`);
		} else if (type === "MerchItem") {
			wrapper = document.getElementById(`merch${id}child${child}`);
		}

		if (wrapper) {
			if (wrapper.dataset.newRecord === "true") {
				// For newly created registrations
				wrapper.remove();
			} else {
				// For existing registrations
				const destroy = wrapper.querySelector("input[name*='_destroy']");
				destroy.value = "1";
				wrapper.classList.remove(`child${child}`);
				if (type === "Option") {
					const cost = wrapper.querySelector(".opt_cost.hidden");
					cost.classList.remove("registered");
				}
			}
		}

		if (name) {
			const nameContainer = document.getElementById("reg-slots");
			nameContainer.childNodes.forEach((node) => {
				if (node.innerText === name.replaceAll("_", " ")) {
					nameContainer.removeChild(node);
				}
			});
		}

		if (snack === "true") {
			const snackCount = parseInt(this.snackCountTarget.innerText);
			this.snackCountTarget.innerText = (snackCount - 1).toString();
		}

		this.dispatch("remove");
	}
}
