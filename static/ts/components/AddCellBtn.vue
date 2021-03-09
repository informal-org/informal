<template>
    <button class="list-group-item list-group-item-action AddItem btn-secondary" @mousedown="addCell">
        <i class="fas fa-plus"></i>
        Add Cell
    </button>
</template>

<script lang="ts">
import Vue from "vue";
import {Group, Value} from "../engine/engine";

export default Vue.component('AddCellBtn', {
    name: 'AddCellBtn',
    props: {
        'group': {type: Group},
    },
    methods: {
        addCell: function(event: Event) {
            let c = new Value("", this.group);
            // Select it for editing.
            this.$store.commit("setEdit", c);
        },
    }
});
</script>

<style>
</style>
