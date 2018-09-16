<template>
    <!-- <li class="list-group-item DataGroup"> -->
    <span>

        <!-- <template v-if="$store.state.editCell === group">
            <DestructBtn v-bind:cell="group"></DestructBtn>

            <input maxlength="20" class="DataLabel" v-model="group.name" placeholder="Name..."/>
        </template>
        <div v-else @mousedown="select">
            <label class="DataLabel">{{ group.name }}&nbsp;</label>
        </div> -->

        <Cell-List v-bind:cells="group.expr" v-bind:addTo="group" v-bind:readonly="readonly"></Cell-List>

        <Cell-Errors v-bind:cell="group"></Cell-Errors>

    </span>
</template>

<script lang="ts">
import Vue from "vue";
import {Group, Value} from "../engine/engine";

export default Vue.component('GroupView', {
    name: 'GroupView',
    props: {
        'group': {type: Group},
        'readonly': {type: Boolean, default: false}
    },
    methods: {
        select: function(event: Event) {
            this.$store.commit("setEdit", this.group);
        }

    },
});
</script>

<style>
</style>
