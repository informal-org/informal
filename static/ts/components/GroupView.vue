<template>
    <li class="list-group-item DataGroup">

        <template v-if="$store.state.editCell === group">
            <DestructBtn v-bind:cell="group"></DestructBtn>

            <input maxlength="20" class="DataLabel" v-model="group.name" placeholder="Name..."/>
        </template>
        <div v-else @mousedown="select">
            <label class="DataLabel">{{ group.name }}&nbsp;</label>
        </div>

        <Cell-List v-bind:cells="group.expr"></Cell-List>

        <template>
            <a class="list-group-item list-group-item-action AddItem" @mousedown="addCell">
                <i class="fas fa-plus"></i>
                Add Cell
                </a>
        </template>

        <Cell-Errors v-bind:cell="group"></Cell-Errors>

    </li>
</template>

<script lang="ts">
import Vue from "vue";
import {Group, Value} from "../engine/engine";

export default Vue.component('GroupView', {
    name: 'GroupView',
    props: {
        'group': {type: Group},
    },
    methods: {
        addCell: function(event: Event) {
            let c = new Value("", this.group);
            // Select it for editing.
            this.$store.commit("setEdit", c);
        },
        select: function(event: Event) {
            this.$store.commit("setEdit", this.group);
        }

    },
});
</script>

<style>
</style>
